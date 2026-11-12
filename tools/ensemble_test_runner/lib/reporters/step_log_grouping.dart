/// Pure helpers for attributing evidence to authored test steps.
///
/// Kept free of Flutter imports so unit tests and the CLI can use them.

/// Walks [stepsOutline] using the pre-order indexes shared by compiled step
/// boundaries. Nested rows keep their own index.
Iterable<({String line, int topLevelIndex, bool nested})>
    stepOutlineTopLevelIndexes(
  List<String> stepsOutline,
) sync* {
  for (var index = 0; index < stepsOutline.length; index++) {
    final line = stepsOutline[index];
    yield (line: line, topLevelIndex: index, nested: line.startsWith('  '));
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

/// Groups events and artifacts by authored step outline index.
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
  List<Map<String, dynamic>> secureStorageSteps = const [],
  List<Map<String, dynamic>> keychainSteps = const [],
  List<Map<String, dynamic>> screenshotFrames = const [],
}) {
  final result = <Map<String, dynamic>>[];
  if (stepsOutline.isEmpty) return result;

  final indexes = stepOutlineTopLevelIndexes(stepsOutline).toList();
  final stepCount = indexes.length;

  final buckets = List.generate(
    stepsOutline.length,
    (index) => <String, dynamic>{
      'stepText': stepsOutline[index],
      'apiCalls': <Map<String, dynamic>>[],
      'appLogs': <String>[],
      'storageChanges': <Map<String, dynamic>>[],
      'secureStorageChanges': <Map<String, dynamic>>[],
      'keychainChanges': <Map<String, dynamic>>[],
      'screenshots': <Map<String, dynamic>>[],
      'observer': null,
    },
  );

  DateTime? windowStart(int stepIndex) {
    if (stepIndex < 0 || stepIndex >= stepStartTimes.length) {
      return null;
    }
    try {
      return DateTime.parse(stepStartTimes[stepIndex]);
    } catch (_) {
      return null;
    }
  }

  DateTime? windowEnd(int stepIndex, DateTime start) {
    if (stepIndex < 0 || stepIndex >= stepDurationsMs.length) {
      return null;
    }
    final durationMs = stepDurationsMs[stepIndex];
    if (durationMs < 0) return null;
    return start.add(Duration(milliseconds: durationMs));
  }

  bool inWindow(DateTime t, int stepIndex) {
    final start = windowStart(stepIndex);
    if (start == null) return false;
    final end = windowEnd(stepIndex, start);
    if (end == null) return false;
    final lo = start.subtract(const Duration(milliseconds: 50));
    final hi = end.add(const Duration(milliseconds: 50));
    return !t.isBefore(lo) && !t.isAfter(hi);
  }

  int? outlineIndexForTopLevel(int stepIndex) =>
      stepIndex >= 0 && stepIndex < buckets.length ? stepIndex : null;

  int? resolveTopLevel(Map<String, dynamic> ev) {
    final stepIndexRaw = ev['stepIndex'];
    final stepIndex =
        stepIndexRaw is int ? stepIndexRaw : int.tryParse('$stepIndexRaw');
    if (stepIndex != null) return stepIndex;
    final timestampStr = ev['timestamp']?.toString();
    if (timestampStr == null) return null;
    try {
      final t = DateTime.parse(timestampStr);
      for (var ti = 0; ti < stepCount; ti++) {
        if (inWindow(t, ti)) return ti;
      }
    } catch (_) {}
    return null;
  }

  for (final ev in apiEvents) {
    // A completion outside an authored step must remain outside the step
    // timeline. Timestamp fallback would otherwise attach a just-after-boundary
    // response to the step that already observed the request as pending.
    if (ev['phase'] == 'completed' && ev['stepIndex'] == null) continue;
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
      for (var ti = 0; ti < stepCount; ti++) {
        if (inWindow(parsed.timestamp!, ti)) {
          targetTopLevel = ti;
          break;
        }
      }
    }
    targetTopLevel ??= 0;
    final outlineIndex = outlineIndexForTopLevel(targetTopLevel);
    if (outlineIndex == null) continue;
    (buckets[outlineIndex]['appLogs'] as List<String>).add(line);
  }

  void addStorageSteps(
    List<Map<String, dynamic>> steps,
    String bucketName,
  ) {
    for (final step in steps) {
      final targetTopLevel = resolveTopLevel(step);
      if (targetTopLevel == null) continue;
      final outlineIndex = outlineIndexForTopLevel(targetTopLevel);
      if (outlineIndex == null) continue;
      final changes = step['changes'];
      if (changes is! List) continue;
      final bucket = buckets[outlineIndex][bucketName] as List;
      for (final change in changes) {
        if (change is Map) {
          bucket.add(Map<String, dynamic>.from(change));
        }
      }
    }
  }

  addStorageSteps(storageSteps, 'storageChanges');
  addStorageSteps(secureStorageSteps, 'secureStorageChanges');
  addStorageSteps(keychainSteps, 'keychainChanges');

  for (final frame in screenshotFrames) {
    final targetTopLevel = resolveTopLevel(frame);
    if (targetTopLevel == null) continue;
    final outlineIndex = outlineIndexForTopLevel(targetTopLevel);
    if (outlineIndex == null) continue;
    if (frame['role']?.toString() == 'observer') {
      // Elements + overlays only — no separate observer PNG in Screenshots.
      buckets[outlineIndex]['observer'] = {
        if (frame['observationJson'] is Map)
          'observationJson':
              Map<String, dynamic>.from(frame['observationJson'] as Map),
        if (frame['overlays'] is List)
          'overlays': List<dynamic>.from(frame['overlays'] as List),
      };
      continue;
    }
    (buckets[outlineIndex]['screenshots'] as List).add(frame);
  }

  for (var i = 0; i < indexes.length; i++) {
    result.add(buckets[i]);
  }

  return result;
}
