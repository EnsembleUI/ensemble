/// Structured error codes for [TestExecutionSession] leaf operations.
enum TestExecutionErrorCode {
  elementNotFound,
  ambiguousTarget,
  staleObservation,
  elementNotInteractable,
  unsupportedAction,
  actionTimeout,
  cancelled,
  executionUnavailable,
  permissionDenied,
  internalError,
}

/// Machine-readable failure for observe/act/wait/assert results.
class TestExecutionError implements Exception {
  final TestExecutionErrorCode code;
  final String message;
  final Map<String, dynamic> details;

  const TestExecutionError({
    required this.code,
    required this.message,
    this.details = const {},
  });

  Map<String, dynamic> toJson() => {
        'code': code.name,
        'message': message,
        if (details.isNotEmpty) 'details': details,
      };

  factory TestExecutionError.fromJson(Map<String, dynamic> json) {
    final codeName = json['code']?.toString() ?? 'internalError';
    final code = TestExecutionErrorCode.values.firstWhere(
      (c) => c.name == codeName,
      orElse: () => TestExecutionErrorCode.internalError,
    );
    final detailsRaw = json['details'];
    return TestExecutionError(
      code: code,
      message: json['message']?.toString() ?? '',
      details:
          detailsRaw is Map ? Map<String, dynamic>.from(detailsRaw) : const {},
    );
  }

  @override
  String toString() => message;
}
