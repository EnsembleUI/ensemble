/// Pure helpers for attributing API/console/storage logs to top-level test steps.
///
/// Kept free of Flutter imports so unit tests and the CLI can use them.

/// Walks [stepsOutline] and yields each line with its top-level step index.
///
/// Nested outline lines (indented with two spaces) inherit the parent index.
Iterable<({String line, int topLevelIndex, bool nested})> stepOutlineTopLevelIndexes(
  List<String> stepsOutline,
) sync* {
  var topLevelIndex = -1;
  for (final line in stepsOutline) {
    final nested = line.startsWith('  ');
    if (!nested) {
      topLevelIndex++;
    }
    if (topLevelIndex < 0) continue;
    yield (line: line, topLevelIndex: topLevelIndex, nested: nested);
  }
}

/// Parses a console log line produced by [TestRuntimeState.formatConsoleLine].
///
/// Expected forms:
/// - `[iso8601] message`
/// - `[iso8601][step=N] message`
({DateTime? timestamp, int? stepIndex, String message}) parseConsoleLogLine(
  String line,
) {
  if (!line.startsWith('[')) {
    return (timestamp: null, stepIndex: null, message: line);
  }
  final firstClose = line.indexOf(']');
  if (firstClose <= 1) {
    return (timestamp: null, stepIndex: null, message: line);
  }
  DateTime? timestamp;
  try {
    timestamp = DateTime.parse(line.substring(1, firstClose));
  } catch (_) {
    return (timestamp: null, stepIndex: null, message: line);
  }

  var rest = line.substring(firstClose + 1);
  int? stepIndex;
  if (rest.startsWith('[step=')) {
    final stepClose = rest.indexOf(']');
    if (stepClose > 6) {
      stepIndex = int.tryParse(rest.substring(6, stepClose));
      rest = rest.substring(stepClose + 1);
    }
  }
  final message = rest.startsWith(' ') ? rest.substring(1) : rest;
  return (timestamp: timestamp, stepIndex: stepIndex, message: message);
}

/// Groups API events, console lines, and storage diffs by top-level step outline index.
///
/// Prefers explicit `stepIndex` on events / `[step=N]` on console lines.
/// Falls back to [stepStartTimes] + [stepDurationsMs] time windows when
/// `stepIndex` is absent (older artifacts).
List<Map<String, dynamic>> groupLogsByStep({
  required List<String> stepsOutline,
  required List<int> stepDurationsMs,
  required List<String> stepStartTimes,
  required List<Map<String, dynamic>> apiEvents,
  required List<String> rawConsoleLines,
  List<Map<String, dynamic>> storageSteps = const [],
  List<Map<String, dynamic>> screenshotFrames = const [],
}) {
  final result = <Map<String, dynamic>>[];
  if (stepsOutline.isEmpty) return result;

  final indexes = stepOutlineTopLevelIndexes(stepsOutline).toList();
  final topLevelCount = indexes.isEmpty
      ? 0
      : indexes.map((e) => e.topLevelIndex).reduce((a, b) => a > b ? a : b) + 1;

  final buckets = List.generate(
    stepsOutline.length,
    (index) => <String, dynamic>{
      'stepText': stepsOutline[index],
      'apiCalls': <Map<String, dynamic>>[],
      'appLogs': <String>[],
      'storageChanges': <Map<String, dynamic>>[],
      'screenshots': <Map<String, dynamic>>[],
    },
  );

  DateTime? windowStart(int topLevelIndex) {
    if (topLevelIndex < 0 || topLevelIndex >= stepStartTimes.length) {
      return null;
    }
    try {
      return DateTime.parse(stepStartTimes[topLevelIndex]);
    } catch (_) {
      return null;
    }
  }

  DateTime? windowEnd(int topLevelIndex, DateTime start) {
    if (topLevelIndex < 0 || topLevelIndex >= stepDurationsMs.length) {
      return null;
    }
    return start.add(Duration(milliseconds: stepDurationsMs[topLevelIndex]));
  }

  bool inWindow(DateTime t, int topLevelIndex) {
    final start = windowStart(topLevelIndex);
    if (start == null) return false;
    final end = windowEnd(topLevelIndex, start);
    if (end == null) return false;
    final lo = start.subtract(const Duration(milliseconds: 50));
    final hi = end.add(const Duration(milliseconds: 50));
    return !t.isBefore(lo) && !t.isAfter(hi);
  }

  int? outlineIndexForTopLevel(int topLevelIndex) {
    for (var i = 0; i < indexes.length; i++) {
      if (!indexes[i].nested && indexes[i].topLevelIndex == topLevelIndex) {
        return i;
      }
    }
    return null;
  }

  int? resolveTopLevel(Map<String, dynamic> ev) {
    final stepIndexRaw = ev['stepIndex'];
    final stepIndex = stepIndexRaw is int
        ? stepIndexRaw
        : int.tryParse('$stepIndexRaw');
    if (stepIndex != null) return stepIndex;
    final timestampStr = ev['timestamp']?.toString();
    if (timestampStr == null) return null;
    try {
      final t = DateTime.parse(timestampStr);
      for (var ti = 0; ti < topLevelCount; ti++) {
        if (inWindow(t, ti)) return ti;
      }
    } catch (_) {}
    return null;
  }

  for (final ev in apiEvents) {
    final targetTopLevel = resolveTopLevel(ev);
    if (targetTopLevel == null) continue;
    final outlineIndex = outlineIndexForTopLevel(targetTopLevel);
    if (outlineIndex == null) continue;
    (buckets[outlineIndex]['apiCalls'] as List).add(ev);
  }

  for (final line in rawConsoleLines) {
    final parsed = parseConsoleLogLine(line);
    int? targetTopLevel = parsed.stepIndex;
    if (targetTopLevel == null && parsed.timestamp != null) {
      for (var ti = 0; ti < topLevelCount; ti++) {
        if (inWindow(parsed.timestamp!, ti)) {
          targetTopLevel = ti;
          break;
        }
      }
    }
    if (targetTopLevel == null) continue;
    final outlineIndex = outlineIndexForTopLevel(targetTopLevel);
    if (outlineIndex == null) continue;
    (buckets[outlineIndex]['appLogs'] as List<String>).add(line);
  }

  for (final step in storageSteps) {
    final targetTopLevel = resolveTopLevel(step);
    if (targetTopLevel == null) continue;
    final outlineIndex = outlineIndexForTopLevel(targetTopLevel);
    if (outlineIndex == null) continue;
    final changes = step['changes'];
    if (changes is! List) continue;
    final bucket = buckets[outlineIndex]['storageChanges'] as List;
    for (final change in changes) {
      if (change is Map) {
        bucket.add(Map<String, dynamic>.from(change));
      }
    }
  }

  for (final frame in screenshotFrames) {
    final targetTopLevel = resolveTopLevel(frame);
    if (targetTopLevel == null) continue;
    final outlineIndex = outlineIndexForTopLevel(targetTopLevel);
    if (outlineIndex == null) continue;
    (buckets[outlineIndex]['screenshots'] as List).add(frame);
  }

  // Nested outline rows keep stepText only — payloads stay on the parent
  // non-nested step (viewers expand/inherit when rendering Step Details).
  for (var i = 0; i < indexes.length; i++) {
    if (!indexes[i].nested) {
      result.add(buckets[i]);
      continue;
    }
    result.add({
      'stepText': indexes[i].line,
      'apiCalls': <Map<String, dynamic>>[],
      'appLogs': <String>[],
      'storageChanges': <Map<String, dynamic>>[],
      'screenshots': <Map<String, dynamic>>[],
    });
  }

  return result;
}
