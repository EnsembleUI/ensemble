import 'dart:async';

/// Runs cleanup after [body] fails without allowing cleanup to replace the
/// body failure.
///
/// This is used by lifecycle adapters that own resources before the shared
/// attempt boundary is entered. Cleanup diagnostics are reported through
/// [onCleanupFailure], while the original error and stack remain observable.
Future<T> runWithCleanupPreservingPrimary<T>({
  required Future<T> Function() body,
  required Future<void> Function() cleanup,
  required void Function(Object error, StackTrace stackTrace) onCleanupFailure,
}) async {
  try {
    return await body();
  } catch (bodyError, bodyStackTrace) {
    try {
      await cleanup();
    } catch (cleanupError, cleanupStackTrace) {
      try {
        onCleanupFailure(cleanupError, cleanupStackTrace);
      } catch (_) {
        // Diagnostics must not replace the failure that caused cleanup.
      }
    }
    Error.throwWithStackTrace(bodyError, bodyStackTrace);
  }
}
