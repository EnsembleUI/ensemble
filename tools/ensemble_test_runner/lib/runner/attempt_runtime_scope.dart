import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/live_async_call.dart';

/// Owns the process-wide runtime hooks installed for one test attempt.
///
/// Both the standalone and application-owned entry points execute in the same
/// Flutter isolate. Keeping installation and restoration here makes an
/// attempt boundary explicit and prevents a failed attempt from leaking its
/// error handler, async runner, or console capture into the next retry.
final class AttemptRuntimeScope {
  AttemptRuntimeScope({
    required this.context,
    required this.tester,
    this.formatFlutterError = _defaultFlutterError,
    VoidCallback Function()? captureDebugPrint,
  }) : _captureDebugPrint =
            captureDebugPrint ?? context.runtime.captureDebugPrint;

  final EnsembleTestContext context;
  final WidgetTester tester;
  final String Function(FlutterErrorDetails details) formatFlutterError;
  final VoidCallback Function() _captureDebugPrint;

  FlutterExceptionHandler? _previousOnError;
  Future<T?> Function<T>(Future<T> Function())? _previousRunner;
  Future<T?> Function<T>(Future<T> Function())? _previousPlatformHttpRunner;
  Future<T?> Function<T>(Future<T> Function())? _previousOverlayRunner;
  VoidCallback? _restoreDebugPrint;
  final List<({Object error, StackTrace stackTrace})> _closeFailures = [];
  bool _open = false;

  /// Every failure encountered while restoring process-wide runtime hooks.
  ///
  /// [close] still throws the first failure for callers that only need a
  /// success/failure signal. The attempt boundary reads this list so later
  /// restoration errors are not silently discarded from attempt reporting.
  List<({Object error, StackTrace stackTrace})> get closeFailures =>
      List.unmodifiable(_closeFailures);

  /// Installs attempt-local hooks. Calling this twice is an error.
  void open() {
    if (_open) {
      throw StateError('Attempt runtime scope is already open.');
    }
    _open = true;
    _previousOnError = FlutterError.onError;
    _previousRunner = LiveAsyncCallSupport.runner;
    _previousPlatformHttpRunner = LiveAsyncCallSupport.platformHttpRunner;
    _previousOverlayRunner = context.apiOverlay.liveAsyncRunner;
    try {
      _restoreDebugPrint = _captureDebugPrint();

      FlutterError.onError = (details) {
        context.runtime.flutterErrors.add(formatFlutterError(details));
        FlutterError.presentError(details);
      };
      Future<T?> runAppAsync<T>(Future<T> Function() callback) =>
          context.runtime.runAsyncWithConsoleCapture(tester, callback);
      context.apiOverlay.liveAsyncRunner = runAppAsync;
      LiveAsyncCallSupport.runner = runAppAsync;
      LiveAsyncCallSupport.platformHttpRunner = tester.runAsync;
    } catch (error, stackTrace) {
      try {
        close();
      } catch (_) {
        // Keep the hook-installation failure primary. The attempt boundary
        // reads closeFailures after this rollback and reports every restore
        // failure as secondary evidence.
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Restores the hooks that were active before [open].
  void close() {
    if (!_open) return;
    _open = false;
    _closeFailures.clear();

    void restore(void Function() callback) {
      try {
        callback();
      } catch (error, stackTrace) {
        _closeFailures.add((error: error, stackTrace: stackTrace));
      }
    }

    // Each hook is process-wide. Restore every hook even if one adapter-owned
    // restoration callback fails, so a failed attempt cannot poison a retry.
    restore(() => FlutterError.onError = _previousOnError);
    final restoreDebugPrint = _restoreDebugPrint;
    if (restoreDebugPrint != null) restore(restoreDebugPrint);
    restore(() => LiveAsyncCallSupport.runner = _previousRunner);
    restore(() =>
        LiveAsyncCallSupport.platformHttpRunner = _previousPlatformHttpRunner);
    restore(() => context.apiOverlay.liveAsyncRunner = _previousOverlayRunner);

    if (_closeFailures.isNotEmpty) {
      final firstFailure = _closeFailures.first;
      Error.throwWithStackTrace(firstFailure.error, firstFailure.stackTrace);
    }
  }
}

String _defaultFlutterError(FlutterErrorDetails details) {
  final context = details.context?.toDescription();
  final exception = details.exceptionAsString();
  if (context == null || context.isEmpty) return exception;
  return '$context: $exception';
}
