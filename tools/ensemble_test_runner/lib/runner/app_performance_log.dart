import 'dart:convert';

import 'package:ensemble_test_runner/mocks/test_api_provider_overlay.dart';
import 'package:ensemble_test_runner/mocks/test_logger.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/test_runtime_state.dart';

Future<String> writeAppPerformanceLog(EnsembleTestContext context) {
  return writePerformanceLog(
    logger: context.logger,
    filePrefix: context.testCase.id,
    name: 'app_performance',
    frames: context.runtime.appFrameTimings,
    markers: context.runtime.performanceMarkers,
    apiCalls: context.apiOverlay.calls,
  );
}

Map<String, dynamic> buildScreenPerformanceJson({
  required String screenName,
  required List<AppFrameTimingEntry> frames,
  required List<PerformanceMarker> markers,
}) {
  final screenMarkers = markers.where((m) => m.screen == screenName).toList();
  final screenFrames = frames.where((f) {
    final marker = _markerForFrame(f, markers);
    return marker?.screen == screenName;
  }).toList();

  final jankyFrames = screenFrames.where((frame) => frame.isJanky).length;
  return {
    'screen': screenName,
    'frameBudgetMs': AppFrameTimingEntry.frameBudgetMs,
    'totalFrames': screenFrames.length,
    'jankyFrames': jankyFrames,
    'jankyFrameRate': _ratio(jankyFrames, screenFrames.length),
    'averageBuildMs': _average(screenFrames.map((frame) => frame.buildMs)),
    'averageRasterMs': _average(screenFrames.map((frame) => frame.rasterMs)),
    'averageTotalSpanMs': _average(screenFrames.map((frame) => frame.totalSpanMs)),
    'markers': screenMarkers.map((m) => _markerJson(m)).toList(),
  };
}

Future<String> writePerformanceLog({
  required TestLogger logger,
  required String filePrefix,
  required String name,
  required List<AppFrameTimingEntry> frames,
  List<PerformanceMarker> markers = const [],
  List<APICallRecord> apiCalls = const [],
}) {
  final jankyFrames = frames.where((frame) => frame.isJanky).length;
  final attributedFrames = frames
      .map((frame) => _AttributedFrame(frame, _markerForFrame(frame, markers)))
      .toList(growable: false);
  final slowestFrames = attributedFrames.toList()
    ..sort((a, b) => b.frame.totalSpanMs.compareTo(a.frame.totalSpanMs));
  final worstSteps = _worstSteps(attributedFrames);
  final worstScreens = _worstScreens(attributedFrames);
  final jankClusters = _jankClusters(attributedFrames);
  final apiCorrelation = _apiCorrelation(attributedFrames, apiCalls);
  final content = const JsonEncoder.withIndent('  ').convert({
    'testId': filePrefix.isEmpty ? 'suite' : filePrefix,
    'frameBudgetMs': AppFrameTimingEntry.frameBudgetMs,
    'summary': {
      'totalFrames': frames.length,
      'jankyFrames': jankyFrames,
      'jankyFrameRate': _ratio(jankyFrames, frames.length),
      'averageBuildMs': _average(frames.map((frame) => frame.buildMs)),
      'averageRasterMs': _average(frames.map((frame) => frame.rasterMs)),
      'averageTotalSpanMs': _average(frames.map((frame) => frame.totalSpanMs)),
      'maxBuildMs': _max(frames.map((frame) => frame.buildMs)),
      'maxRasterMs': _max(frames.map((frame) => frame.rasterMs)),
      'maxTotalSpanMs': _max(frames.map((frame) => frame.totalSpanMs)),
      if (worstSteps.isNotEmpty) 'worstStep': worstSteps.first['step'],
      if (worstScreens.isNotEmpty) 'worstScreen': worstScreens.first['screen'],
    },
    'totalFrames': frames.length,
    'jankyFrames': jankyFrames,
    'jankyFrameRate': _ratio(jankyFrames, frames.length),
    'averageBuildMs': _average(frames.map((frame) => frame.buildMs)),
    'averageRasterMs': _average(frames.map((frame) => frame.rasterMs)),
    'averageTotalSpanMs': _average(frames.map((frame) => frame.totalSpanMs)),
    'maxBuildMs': _max(frames.map((frame) => frame.buildMs)),
    'maxRasterMs': _max(frames.map((frame) => frame.rasterMs)),
    'maxTotalSpanMs': _max(frames.map((frame) => frame.totalSpanMs)),
    'worstSteps': worstSteps,
    'worstScreens': worstScreens,
    'jankClusters': jankClusters,
    'apiCorrelation': apiCorrelation,
    'slowestFrames':
        slowestFrames.take(10).map((frame) => frame.toJson()).toList(),
    'frames': attributedFrames.map((frame) => frame.toJson()).toList(),
  });

  return logger.writeLogFile(
    testId: filePrefix,
    name: name,
    content: content,
    extension: 'json',
  );
}

PerformanceMarker? _markerForFrame(
  AppFrameTimingEntry frame,
  List<PerformanceMarker> markers,
) {
  for (final marker in markers.reversed) {
    if (marker.containsFrame(frame.frameNumber)) return marker;
  }
  return null;
}

List<Map<String, dynamic>> _worstSteps(List<_AttributedFrame> frames) {
  final byStep = <String, List<_AttributedFrame>>{};
  for (final frame in frames) {
    final marker = frame.marker;
    if (marker == null) continue;
    byStep.putIfAbsent(marker.label, () => []).add(frame);
  }
  final rows = byStep.entries.map((entry) {
    final stepFrames = entry.value;
    final janky = stepFrames.where((frame) => frame.frame.isJanky).toList();
    return {
      'step': entry.key,
      'testId': stepFrames.first.marker?.testId,
      if (stepFrames.first.marker?.stepIndex != null)
        'stepIndex': stepFrames.first.marker?.stepIndex,
      'screen': stepFrames.first.marker?.screen,
      'phase': stepFrames.first.marker?.phase,
      'totalFrames': stepFrames.length,
      'jankyFrames': janky.length,
      'jankyFrameRate': _ratio(janky.length, stepFrames.length),
      'maxTotalSpanMs':
          _max(stepFrames.map((frame) => frame.frame.totalSpanMs)),
      'totalJankOverBudgetMs': _jankOverBudget(janky),
    };
  }).toList()
    ..sort(_rankJankRows);
  return rows.take(10).toList();
}

List<Map<String, dynamic>> _worstScreens(List<_AttributedFrame> frames) {
  final byScreen = <String, List<_AttributedFrame>>{};
  for (final frame in frames) {
    final screen = frame.marker?.screen;
    if (screen == null || screen.isEmpty) continue;
    byScreen.putIfAbsent(screen, () => []).add(frame);
  }
  final rows = byScreen.entries.map((entry) {
    final screenFrames = entry.value;
    final janky = screenFrames.where((frame) => frame.frame.isJanky).toList();
    return {
      'screen': entry.key,
      'totalFrames': screenFrames.length,
      'jankyFrames': janky.length,
      'jankyFrameRate': _ratio(janky.length, screenFrames.length),
      'maxTotalSpanMs':
          _max(screenFrames.map((frame) => frame.frame.totalSpanMs)),
      'totalJankOverBudgetMs': _jankOverBudget(janky),
    };
  }).toList()
    ..sort(_rankJankRows);
  return rows.take(10).toList();
}

int _rankJankRows(Map<String, dynamic> a, Map<String, dynamic> b) {
  final byJank = (b['jankyFrames'] as int).compareTo(a['jankyFrames'] as int);
  if (byJank != 0) return byJank;
  return (b['maxTotalSpanMs'] as double)
      .compareTo(a['maxTotalSpanMs'] as double);
}

List<Map<String, dynamic>> _jankClusters(List<_AttributedFrame> frames) {
  final clusters = <List<_AttributedFrame>>[];
  var current = <_AttributedFrame>[];
  for (final frame in frames) {
    if (!frame.frame.isJanky) {
      if (current.isNotEmpty) {
        clusters.add(current);
        current = <_AttributedFrame>[];
      }
      continue;
    }
    if (current.isEmpty ||
        frame.frame.frameNumber - current.last.frame.frameNumber <= 2) {
      current.add(frame);
    } else {
      clusters.add(current);
      current = [frame];
    }
  }
  if (current.isNotEmpty) clusters.add(current);

  final rows = clusters.map((cluster) {
    final slowest = cluster.toList()
      ..sort((a, b) => b.frame.totalSpanMs.compareTo(a.frame.totalSpanMs));
    final marker = slowest.first.marker;
    return {
      'startFrame': cluster.first.frame.frameNumber,
      'endFrame': cluster.last.frame.frameNumber,
      'jankyFrames': cluster.length,
      'maxTotalSpanMs': slowest.first.frame.totalSpanMs,
      'totalJankOverBudgetMs': _jankOverBudget(cluster),
      if (marker != null) ..._markerJson(marker),
    };
  }).toList()
    ..sort(_rankJankRows);
  return rows.take(10).toList();
}

List<Map<String, dynamic>> _apiCorrelation(
  List<_AttributedFrame> frames,
  List<APICallRecord> apiCalls,
) {
  final rows = <Map<String, dynamic>>[];
  final jankyMarkers = frames
      .where((frame) => frame.frame.isJanky && frame.marker != null)
      .map((frame) => frame.marker!)
      .toSet();
  for (final marker in jankyMarkers) {
    final calls = apiCalls
        .where((call) => marker.overlaps(call.timestamp,
            tolerance: const Duration(milliseconds: 250)))
        .toList();
    if (calls.isEmpty) continue;
    rows.add({
      ..._markerJson(marker),
      'apiCalls': [
        for (final call in calls)
          {
            'name': call.name,
            'timestamp': call.timestamp.toIso8601String(),
          },
      ],
    });
  }
  return rows.take(25).toList();
}

double _jankOverBudget(Iterable<_AttributedFrame> frames) {
  return _round(
    frames.fold<double>(
      0,
      (sum, frame) =>
          sum +
          (frame.frame.totalSpanMs - AppFrameTimingEntry.frameBudgetMs)
              .clamp(0, double.infinity),
    ),
  );
}

Map<String, dynamic> _markerJson(PerformanceMarker marker) => {
      'testId': marker.testId,
      if (marker.stepIndex != null) 'stepIndex': marker.stepIndex,
      'step': marker.label,
      if (marker.screen != null) 'screen': marker.screen,
      'phase': marker.phase,
    };

class _AttributedFrame {
  final AppFrameTimingEntry frame;
  final PerformanceMarker? marker;

  const _AttributedFrame(this.frame, this.marker);

  Map<String, dynamic> toJson() => {
        ...frame.toJson(),
        if (marker != null) ..._markerJson(marker!),
      };
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
