import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';

enum AssertionStatus { passed, failed, error }

class AssertionResult {
  final String assertionId;
  final AssertionStatus status;
  final String? message;
  final TestExecutionError? error;

  const AssertionResult({
    required this.assertionId,
    required this.status,
    this.message,
    this.error,
  });

  bool get passed => status == AssertionStatus.passed;

  Map<String, dynamic> toJson() => {
        'assertionId': assertionId,
        'status': status.name,
        if (message != null) 'message': message,
        if (error != null) 'error': error!.toJson(),
      };

  factory AssertionResult.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString() ?? 'failed';
    return AssertionResult(
      assertionId: json['assertionId']?.toString() ?? '',
      status: AssertionStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => AssertionStatus.failed,
      ),
      message: json['message']?.toString(),
      error: json['error'] is Map
          ? TestExecutionError.fromJson(
              Map<String, dynamic>.from(json['error'] as Map),
            )
          : null,
    );
  }
}

enum WaitStatus { satisfied, timedOut, cancelled, failed }

class WaitResult {
  final String waitId;
  final WaitStatus status;
  final Duration duration;
  final TestExecutionError? error;

  const WaitResult({
    required this.waitId,
    required this.status,
    required this.duration,
    this.error,
  });

  bool get satisfied => status == WaitStatus.satisfied;

  Map<String, dynamic> toJson() => {
        'waitId': waitId,
        'status': status.name,
        'durationMs': duration.inMilliseconds,
        if (error != null) 'error': error!.toJson(),
      };

  factory WaitResult.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString() ?? 'failed';
    return WaitResult(
      waitId: json['waitId']?.toString() ?? '',
      status: WaitStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => WaitStatus.failed,
      ),
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      error: json['error'] is Map
          ? TestExecutionError.fromJson(
              Map<String, dynamic>.from(json['error'] as Map),
            )
          : null,
    );
  }
}
