/// Chooses the failure to surface when an operation and its cleanup both fail.
///
/// The operation failure stays primary; cleanup becomes primary only when the
/// operation completed successfully.
({Object error, StackTrace stackTrace})? selectPrimaryFailure({
  required Object? operationError,
  required StackTrace? operationStackTrace,
  required Object? cleanupError,
  required StackTrace? cleanupStackTrace,
}) {
  if (operationError != null) {
    return (
      error: operationError,
      stackTrace: operationStackTrace!,
    );
  }
  if (cleanupError != null) {
    return (
      error: cleanupError,
      stackTrace: cleanupStackTrace!,
    );
  }
  return null;
}
