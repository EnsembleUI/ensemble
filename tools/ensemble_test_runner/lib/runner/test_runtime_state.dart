import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Mutable runtime flags and logs for declarative test steps.
class TestRuntimeState {
  bool networkOffline = false;
  final List<String> consoleLogs = [];
  final List<String> flutterErrors = [];
  Map<String, dynamic>? authUser;
  final Map<String, String> permissions = {};
  Size? deviceSize;
  Locale? locale;
  String? themeMode;
  final Map<String, dynamic> fixtures = {};

  void clear() {
    networkOffline = false;
    consoleLogs.clear();
    flutterErrors.clear();
    authUser = null;
    permissions.clear();
    deviceSize = null;
    locale = null;
    themeMode = null;
    fixtures.clear();
  }
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
