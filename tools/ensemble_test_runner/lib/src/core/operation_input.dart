/// The name and arguments needed by a runtime operation handler.
///
/// Authored steps and compiled operations share this input shape so handlers
/// can operate directly on compiled operations without rebuilding a step.
abstract interface class OperationInput {
  String get operationName;

  Map get arguments;
}
