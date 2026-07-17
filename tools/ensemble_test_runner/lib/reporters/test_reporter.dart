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
    session: testCase.session,
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

    if (result.suiteLogs.isNotEmpty) {
      buffer.writeln('│');
      buffer.writeln('│  suite artifacts:');
      for (final log in result.suiteLogs) {
        buffer.writeln('│       $log');
      }
    }

    buffer.writeln('│');
    buffer.writeln(
      '└─ ${result.summary} · ${totalMs}ms total',
    );
    return buffer.toString();
  }

  /// Formats the short failure passed to Flutter's test framework.
  ///
  /// The full boxed report is printed separately. Keeping this compact avoids
  /// Flutter echoing the entire report again with its framework stack trace.
  String formatFailureSummary(
    EnsembleTestRunResult result, {
    Iterable<String> failedPaths = const [],
    Iterable<Object?> pendingFrameworkExceptions = const [],
  }) {
    final failed = result.results
        .where((r) => r.status == TestStatus.failed)
        .toList(growable: false);
    final paths = failedPaths.toList(growable: false);
    final buffer = StringBuffer()
      ..writeln(
        'Failed YAML tests (${result.failedCount}/${result.results.length}):',
      );

    for (var i = 0; i < failed.length; i++) {
      final r = failed[i];
      final path = i < paths.length ? paths[i] : null;
      final label = path == null || r.testId.contains(path)
          ? r.testId
          : '${r.testId} ($path)';
      final failedStep = r.failedStep != null
          ? ' (failed: ${formatStepBrief(r.failedStep!)})'
          : r.failedStepIndex != null
              ? ' (failed: step ${r.failedStepIndex! + 1})'
              : '';
      buffer.writeln('- $label: ${r.message ?? 'failed'}$failedStep');
    }

    final pending = pendingFrameworkExceptions
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (pending.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Pending Flutter framework exceptions:');
      for (final exception in pending) {
        buffer.writeln('- ${_firstLine(exception)}');
      }
    }

    buffer.writeln();
    buffer.write('See the Ensemble YAML tests report above.');
    return buffer.toString();
  }

  void _writeTestCase(StringBuffer buffer, EnsembleSingleTestResult r) {
    final icon = r.status == TestStatus.passed ? '✓' : '✗';
    buffer.writeln('│  $icon ${r.testId} (${r.durationMs}ms)');
    if (r.attempts > 1) {
      buffer.writeln('│     attempts: ${r.attempts}/${r.retry + 1}');
    }

    final report = r.report;
    if (report != null) {
      if (report.prerequisite != null) {
        buffer.writeln('│     after: ${report.prerequisite}');
      }
      if (report.session != null) {
        buffer.writeln('│     session: ${report.session}');
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

String _firstLine(String value) {
  final index = value.indexOf('\n');
  return index == -1 ? value : value.substring(0, index);
}
