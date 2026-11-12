import 'package:ensemble_test_runner/models/ensemble_test_models.dart';

/// Pure-Dart helpers for rendering step outlines with optional durations.
///
/// Kept free of Flutter / Ensemble imports so the CLI (`dart run`) can use them.

/// Formats a step outline line with optional duration, e.g. `tap(x) (42ms)`.
String formatStepOutlineLine(String label, int? durationMs) {
  if (durationMs == null) return label;
  return '$label (${durationMs}ms)';
}

/// Short label for a step, e.g. `expectVisible(greeting_text)`.
String formatStepBrief(TestStep step) {
  final type = step.type;
  final args = step.args;

  if (type == 'optional' && step.nestedSteps.length == 1) {
    return '$type(${formatStepBrief(step.nestedSteps.single)})';
  }

  String? detail;
  final id = args['id'];
  if (id != null) {
    final action = args['action'];
    detail = action != null ? '$action $id' : id.toString();
  } else if (args['screen'] != null) {
    detail = args['screen'].toString();
  } else if (args['name'] != null) {
    detail = args['name'].toString();
  } else if (args['text'] != null) {
    var text = args['text'].toString();
    if (text.length > 40) {
      text = '${text.substring(0, 37)}...';
    }
    detail = '"$text"';
  } else if (args['value'] != null) {
    detail = args['value'].toString();
  }

  if (detail == null && args.isNotEmpty) {
    final entry = args.entries.first;
    detail = '${entry.key}=${entry.value}';
  }

  return detail != null ? '$type($detail)' : type;
}

/// Walks [stepsOutline] with [stepDurationsMs] / [failedStepIndex] for display.
///
/// Outline rows and compiled step indexes use the same pre-order, including
/// nested children. Control rows can have no duration and use `-1` as the
/// sparse placeholder for a skipped branch.
Iterable<({String text, bool failed, int? durationMs})>
    stepOutlineDisplayLines({
  required List<String> stepsOutline,
  List<int> stepDurationsMs = const [],
  int? failedStepIndex,
}) sync* {
  for (var index = 0; index < stepsOutline.length; index++) {
    final line = stepsOutline[index];
    final duration =
        index < stepDurationsMs.length ? stepDurationsMs[index] : -1;
    final durationMs = duration >= 0 ? duration : null;
    final failed = failedStepIndex != null && failedStepIndex == index;
    yield (
      text: formatStepOutlineLine(line, durationMs),
      failed: failed,
      durationMs: durationMs,
    );
  }
}
