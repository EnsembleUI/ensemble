import 'package:flutter/foundation.dart';

/// Keeps framework diagnostics visible in the console without forwarding them
/// to flutter_test's binding, which treats any unconsumed FlutterError as a
/// failure of the single enclosing testWidgets callback.
///
/// The YAML runner has its own per-step and per-test result boundaries. A
/// framework diagnostic alone must not escape those boundaries and terminate
/// the suite.
Future<T> withFlutterErrorIsolation<T>(Future<T> Function() run) async {
  final previousOnError = FlutterError.onError;
  FlutterError.onError = FlutterError.presentError;
  try {
    return await run();
  } finally {
    FlutterError.onError = previousOnError;
  }
}
