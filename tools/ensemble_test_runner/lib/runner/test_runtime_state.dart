import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Mutable runtime flags and logs for declarative test steps.
class TestRuntimeState {
  bool networkOffline = false;
  final List<String> consoleLogs = [];
  final List<String> flutterErrors = [];
  final List<AppFrameTimingEntry> appFrameTimings = [];
  final List<Future<void> Function()> pendingScreenshotWrites = [];
  Map<String, dynamic>? authUser;
  final Map<String, String> permissions = {};
  Size? deviceSize;
  Locale? locale;
  String? themeMode;

  void clear() {
    networkOffline = false;
    consoleLogs.clear();
    flutterErrors.clear();
    appFrameTimings.clear();
    pendingScreenshotWrites.clear();
    authUser = null;
    permissions.clear();
    deviceSize = null;
    locale = null;
    themeMode = null;
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

/// Captures Flutter framework errors for quality assertion steps.
class TestErrorTracker {
  static FlutterExceptionHandler? _previousHandler;

  static void install(TestRuntimeState runtime) {
    _previousHandler = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      runtime.flutterErrors.add(details.exceptionAsString());
    };
  }

  static void reset() {
    if (_previousHandler != null) {
      FlutterError.onError = _previousHandler;
      _previousHandler = null;
    }
  }
}
