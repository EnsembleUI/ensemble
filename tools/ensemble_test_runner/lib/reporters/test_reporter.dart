import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';

EnsembleTestReportDetails buildTestReportDetails(EnsembleTestCase testCase) {
  final effectiveStart = testCase.startScreen ??
      ScreenTracker().getCurrentScreenIdentifier() ??
      '(unknown)';
  final details = EnsembleTestReportDetails(
    startScreen: effectiveStart,
    endScreen: ScreenTracker().getCurrentScreenIdentifier(),
    prerequisite: testCase.prerequisite,
    screensVisited: collectScreensVisited(effectiveStart),
    stepsOutline: outlineSteps(testCase.steps),
  );
  return details;
}

List<String> collectScreensVisited(String effectiveStart) {
  final flow = List<String>.from(YamlTestSession.navigationFlow.flow);
  if (flow.isEmpty) {
    return [effectiveStart];
  }
  if (flow.first != effectiveStart) {
    return [effectiveStart, ...flow];
  }
  return flow;
}

List<String> outlineSteps(List<TestStep> steps) {
  final lines = <String>[];
  for (final step in steps) {
    lines.addAll(_outlineStep(step));
  }
  return lines;
}

List<String> _outlineStep(TestStep step) {
  if (step.nestedSteps.isNotEmpty) {
    final nested = outlineSteps(step.nestedSteps);
    return [
      '${step.type} (${nested.length} steps)',
      ...nested.map((line) => '  $line'),
    ];
  }
  return [formatStepBrief(step)];
}

/// Short label for a step, e.g. `expectVisible(greeting_text)`.
String formatStepBrief(TestStep step) {
  final type = step.type;
  final args = step.args;

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

class TestReporter {
  /// Formats a multi-test run report for console output.
  String formatSummary(
    EnsembleTestRunResult result, {
    String? testFile,
  }) {
    final buffer = StringBuffer();
    final totalMs = result.results.fold<int>(0, (sum, r) => sum + r.durationMs);

    buffer.writeln('┌─ Ensemble YAML tests ─────────────────────────────');
    if (testFile != null) {
      buffer.writeln('│  $testFile');
      buffer.writeln('│');
    }

    for (var i = 0; i < result.results.length; i++) {
      final r = result.results[i];
      if (i > 0) buffer.writeln('│');
      _writeTestCase(buffer, r);
    }

    buffer.writeln('│');
    buffer.writeln(
      '└─ ${result.summary} · ${totalMs}ms total',
    );
    return buffer.toString();
  }

  void _writeTestCase(StringBuffer buffer, EnsembleSingleTestResult r) {
    final icon = r.status == TestStatus.passed ? '✓' : '✗';
    buffer.writeln('│  $icon ${r.testId} (${r.durationMs}ms)');

    final report = r.report;
    if (report != null) {
      if (report.prerequisite != null) {
        buffer.writeln('│     after: ${report.prerequisite}');
      }
      buffer.writeln('│     start: ${report.startScreen}');
      if (report.endScreen != null && report.endScreen != report.startScreen) {
        buffer.writeln('│     end:   ${report.endScreen}');
      }
      if (report.screensVisited.length > 1) {
        buffer.writeln('│     flow:  ${report.screensVisited.join(' → ')}');
      }
      if (report.stepsOutline.isNotEmpty) {
        buffer.writeln('│     steps (${report.stepsOutline.length}):');
        for (var i = 0; i < report.stepsOutline.length; i++) {
          final prefix = r.status == TestStatus.failed && r.failedStepIndex == i
              ? '>>'
              : '  ';
          buffer.writeln('│       $prefix ${i + 1}. ${report.stepsOutline[i]}');
        }
      }
    }

    if (r.status == TestStatus.failed) {
      if (r.message != null) {
        buffer.writeln('│     error: ${r.message}');
      }
      if (r.failedStep != null) {
        buffer.writeln('│     failed: ${formatStepBrief(r.failedStep!)}');
      } else if (r.failedStepIndex != null) {
        buffer.writeln('│     at step: ${r.failedStepIndex! + 1}');
      }
    }

    if (r.logs.isNotEmpty) {
      buffer.writeln('│     artifacts:');
      for (final log in r.logs) {
        buffer.writeln('│          $log');
      }
    }
  }
}
