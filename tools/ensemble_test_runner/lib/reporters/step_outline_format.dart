/// Pure-Dart helpers for rendering step outlines with optional durations.
///
/// Kept free of Flutter / Ensemble imports so the CLI (`dart run`) can use them.

/// Formats a step outline line with optional duration, e.g. `tap(x) (42ms)`.
String formatStepOutlineLine(String label, int? durationMs) {
  if (durationMs == null) return label;
  return '$label (${durationMs}ms)';
}

/// Walks [stepsOutline] with [stepDurationsMs] / [failedStepIndex] for display.
///
/// Nested outline lines (indented with two spaces) get no duration; duration and
/// failure highlighting apply to top-level lines only.
Iterable<({String text, bool failed, int? durationMs})> stepOutlineDisplayLines({
  required List<String> stepsOutline,
  List<int> stepDurationsMs = const [],
  int? failedStepIndex,
}) sync* {
  var topLevelIndex = -1;
  for (final line in stepsOutline) {
    final nested = line.startsWith('  ');
    if (!nested) {
      topLevelIndex++;
    }
    final durationMs = !nested && topLevelIndex < stepDurationsMs.length
        ? stepDurationsMs[topLevelIndex]
        : null;
    final failed =
        !nested && failedStepIndex != null && failedStepIndex == topLevelIndex;
    yield (
      text: formatStepOutlineLine(line, durationMs),
      failed: failed,
      durationMs: durationMs,
    );
  }
}
