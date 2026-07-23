import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ensemble_test_runner/runner/storage_step_diff.dart';
import 'package:flutter/material.dart';

/// Mutable runtime flags and logs for declarative test steps.
class TestRuntimeState {
  bool networkOffline = false;
  final List<String> consoleLogs = [];
  final List<String> flutterErrors = [];
  final List<AppFrameTimingEntry> appFrameTimings = [];
  final List<PerformanceMarker> performanceMarkers = [];
  final List<ScreenshotSheetFrame> screenshotSheetFrames = [];
  Map<String, dynamic>? authUser;
  final Map<String, String> permissions = {};
  Size? deviceSize;
  Locale? locale;
  String? themeMode;

  /// Active top-level step index while [_executeSteps] runs (0-based).
  /// Used to attribute API calls and console lines to Step Details.
  int? currentStepIndex;

  /// Public-storage diffs captured at the end of each top-level step.
  final List<StorageStepDiff> storageStepDiffs = [];

  /// Map from screen name to its captured artifacts (debugTree, performance markers, etc.)
  final Map<String, Map<String, dynamic>> screenArtifacts = {};

  void clear() {
    networkOffline = false;
    consoleLogs.clear();
    flutterErrors.clear();
    appFrameTimings.clear();
    performanceMarkers.clear();
    screenshotSheetFrames.clear();
    authUser = null;
    permissions.clear();
    deviceSize = null;
    locale = null;
    themeMode = null;
    currentStepIndex = null;
    storageStepDiffs.clear();
    screenArtifacts.clear();
  }

  /// Console prefix with ISO timestamp and optional `[step=N]` tag.
  String formatConsoleLine(String message) {
    final ts = DateTime.now().toIso8601String();
    final step = currentStepIndex;
    if (step == null) return '[$ts] $message';
    return '[$ts][step=$step] $message';
  }

  void addFrameTimings(List<ui.FrameTiming> timings) {
    for (final timing in timings) {
      appFrameTimings.add(
        AppFrameTimingEntry.fromFrameTiming(
          frameNumber: appFrameTimings.length + 1,
          timing: timing,
        ),
      );
    }
  }

  void recordPerformanceMarker(PerformanceMarker marker) {
    performanceMarkers.add(marker);
  }

  void addScreenshotSheetFrame(ScreenshotSheetFrame frame) {
    screenshotSheetFrames.add(frame);
  }
}

class ScreenshotSheetFrame {
  final int stepIndex;
  final String label;
  final ui.Image image;
  final String? deviceId;
  final String? deviceLabel;
  final String? platform;
  final String? model;
  Uint8List? encodedPngBytes;

  ScreenshotSheetFrame({
    required this.stepIndex,
    required this.label,
    required this.image,
    this.deviceId,
    this.deviceLabel,
    this.platform,
    this.model,
  });
}

class PerformanceMarker {
  final String testId;
  final int? stepIndex;
  final String label;
  final String? screen;
  final String phase;
  final int startFrame;
  final int endFrame;
  final DateTime startTime;
  final DateTime endTime;

  const PerformanceMarker({
    required this.testId,
    required this.stepIndex,
    required this.label,
    required this.screen,
    required this.phase,
    required this.startFrame,
    required this.endFrame,
    required this.startTime,
    required this.endTime,
  });

  PerformanceMarker shiftedFrames(int offset) => PerformanceMarker(
        testId: testId,
        stepIndex: stepIndex,
        label: label,
        screen: screen,
        phase: phase,
        startFrame: startFrame + offset,
        endFrame: endFrame + offset,
        startTime: startTime,
        endTime: endTime,
      );

  bool containsFrame(int frameNumber) =>
      frameNumber >= startFrame && frameNumber <= endFrame;

  bool overlaps(DateTime timestamp, {Duration tolerance = Duration.zero}) {
    final lower = startTime.subtract(tolerance);
    final upper = endTime.add(tolerance);
    return !timestamp.isBefore(lower) && !timestamp.isAfter(upper);
  }

  Map<String, dynamic> toJson() => {
        'testId': testId,
        if (stepIndex != null) 'stepIndex': stepIndex,
        'label': label,
        if (screen != null) 'screen': screen,
        'phase': phase,
        'startFrame': startFrame,
        'endFrame': endFrame,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
      };
}

class AppFrameTimingEntry {
  static const double frameBudgetMs = 16.67;

  final int frameNumber;
  final int buildStartMicros;
  final double buildMs;
  final double rasterMs;
  final double vsyncOverheadMs;
  final double totalSpanMs;

  const AppFrameTimingEntry({
    required this.frameNumber,
    required this.buildStartMicros,
    required this.buildMs,
    required this.rasterMs,
    required this.vsyncOverheadMs,
    required this.totalSpanMs,
  });

  factory AppFrameTimingEntry.fromFrameTiming({
    required int frameNumber,
    required ui.FrameTiming timing,
  }) {
    return AppFrameTimingEntry(
      frameNumber: frameNumber,
      buildStartMicros: timing.timestampInMicroseconds(
        ui.FramePhase.buildStart,
      ),
      buildMs: _durationMs(timing.buildDuration),
      rasterMs: _durationMs(timing.rasterDuration),
      vsyncOverheadMs: _durationMs(timing.vsyncOverhead),
      totalSpanMs: _durationMs(timing.totalSpan),
    );
  }

  bool get isJanky =>
      totalSpanMs > frameBudgetMs || buildMs + rasterMs > frameBudgetMs;

  Map<String, dynamic> toJson() => {
        'frameNumber': frameNumber,
        'buildStartMicros': buildStartMicros,
        'buildMs': buildMs,
        'rasterMs': rasterMs,
        'vsyncOverheadMs': vsyncOverheadMs,
        'totalSpanMs': totalSpanMs,
        'janky': isJanky,
      };

  static double _durationMs(Duration duration) =>
      double.parse((duration.inMicroseconds / 1000).toStringAsFixed(3));
}
