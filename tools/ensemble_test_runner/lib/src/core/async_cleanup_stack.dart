import 'dart:async';

import 'package:ensemble_test_runner/src/core/primary_failure.dart';

/// Runs registered asynchronous cleanup in reverse registration order.
///
/// Each callback is attempted even when an earlier callback fails. Calling
/// [close] again shares the in-flight cleanup future, which makes it safe to
/// use at multiple overlapping lifecycle boundaries.
final class AsyncCleanupStack {
  final List<FutureOr<void> Function()> _callbacks = [];
  final List<({Object error, StackTrace stackTrace})> _failures = [];
  bool _closed = false;
  Future<void>? _closeFuture;

  /// Every callback failure in reverse execution order. [close] still throws
  /// the first failure so existing callers retain their failure semantics.
  List<({Object error, StackTrace stackTrace})> get failures =>
      List.unmodifiable(_failures);

  void add(FutureOr<void> Function() callback) {
    if (_closed) {
      throw StateError('Cannot register cleanup after the stack is closed.');
    }
    _callbacks.add(callback);
  }

  Future<void> close() {
    final existing = _closeFuture;
    if (existing != null) return existing;
    _closed = true;

    // Publish the future before starting callbacks. A callback can re-enter
    // the stack (for example, timeout teardown and suite teardown may overlap)
    // and must observe the same completion instead of starting a second drain.
    final completer = Completer<void>();
    _closeFuture = completer.future;
    unawaited(_drain(completer));
    return completer.future;
  }

  Future<void> _drain(Completer<void> completer) async {
    for (final callback in _callbacks.reversed) {
      try {
        await callback();
      } catch (error, stackTrace) {
        _failures.add((error: error, stackTrace: stackTrace));
      }
    }
    _callbacks.clear();
    if (_failures.isNotEmpty) {
      final firstFailure = _failures.first;
      completer.completeError(firstFailure.error, firstFailure.stackTrace);
      return;
    }
    completer.complete();
  }

  /// Runs [body] and closes this stack exactly once afterwards.
  ///
  /// The body failure remains primary when cleanup also fails. This gives an
  /// attempt owner one structured boundary for success, failure, timeout, and
  /// cancellation paths without duplicating `try/finally` bookkeeping.
  Future<T> run<T>(Future<T> Function() body) async {
    Object? bodyError;
    StackTrace? bodyStackTrace;
    late T value;
    try {
      value = await body();
    } catch (error, stackTrace) {
      bodyError = error;
      bodyStackTrace = stackTrace;
    }

    Object? cleanupError;
    StackTrace? cleanupStackTrace;
    try {
      await close();
    } catch (error, stackTrace) {
      cleanupError = error;
      cleanupStackTrace = stackTrace;
    }

    final failure = selectPrimaryFailure(
      operationError: bodyError,
      operationStackTrace: bodyStackTrace,
      cleanupError: cleanupError,
      cleanupStackTrace: cleanupStackTrace,
    );
    if (failure != null) {
      Error.throwWithStackTrace(failure.error, failure.stackTrace);
    }
    return value;
  }
}
