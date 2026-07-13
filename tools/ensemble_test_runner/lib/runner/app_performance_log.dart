import 'dart:convert';

import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

Future<String> writeAppPerformanceLog(EnsembleTestContext context) {
  final frames = context.runtime.appFrameTimings;
  final jankyFrames = frames.where((frame) => frame.isJanky).length;
  final slowestFrames = frames.toList()
    ..sort((a, b) => b.totalSpanMs.compareTo(a.totalSpanMs));
  final content = const JsonEncoder.withIndent('  ').convert({
    'testId': context.testCase.id,
    'frameBudgetMs': AppFrameTimingEntry.frameBudgetMs,
    'totalFrames': frames.length,
    'jankyFrames': jankyFrames,
    'jankyFrameRate': _ratio(jankyFrames, frames.length),
    'averageBuildMs': _average(frames.map((frame) => frame.buildMs)),
    'averageRasterMs': _average(frames.map((frame) => frame.rasterMs)),
    'averageTotalSpanMs': _average(frames.map((frame) => frame.totalSpanMs)),
    'maxBuildMs': _max(frames.map((frame) => frame.buildMs)),
    'maxRasterMs': _max(frames.map((frame) => frame.rasterMs)),
    'maxTotalSpanMs': _max(frames.map((frame) => frame.totalSpanMs)),
    'slowestFrames':
        slowestFrames.take(10).map((frame) => frame.toJson()).toList(),
    'frames': frames.map((frame) => frame.toJson()).toList(),
  });

  return context.logger.writeLogFile(
    testId: context.testCase.id,
    name: 'app_performance',
    content: content,
    extension: 'json',
  );
}

double _average(Iterable<double> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return 0;
  return _round(list.reduce((a, b) => a + b) / list.length);
}

double _max(Iterable<double> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return 0;
  return _round(list.reduce((a, b) => a > b ? a : b));
}

double _ratio(int numerator, int denominator) {
  if (denominator == 0) return 0;
  return _round(numerator / denominator);
}

double _round(double value) => double.parse(value.toStringAsFixed(3));
