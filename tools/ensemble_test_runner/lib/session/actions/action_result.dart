import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';

/// Result of [TestExecutionSession.act].
class ActionResult {
  final String actionId;
  final ActionStatus status;
  final int beforeRevision;
  final int afterRevision;
  final Duration duration;
  final TestExecutionError? error;

  const ActionResult({
    required this.actionId,
    required this.status,
    required this.beforeRevision,
    required this.afterRevision,
    required this.duration,
    this.error,
  });

  bool get succeeded => status == ActionStatus.succeeded;

  Map<String, dynamic> toJson() => {
        'actionId': actionId,
        'status': status.name,
        'beforeRevision': beforeRevision,
        'afterRevision': afterRevision,
        'durationMs': duration.inMilliseconds,
        if (error != null) 'error': error!.toJson(),
      };

  factory ActionResult.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString() ?? 'failed';
    final status = ActionStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => ActionStatus.failed,
    );
    final errorRaw = json['error'];
    return ActionResult(
      actionId: json['actionId']?.toString() ?? '',
      status: status,
      beforeRevision: json['beforeRevision'] as int? ?? 0,
      afterRevision: json['afterRevision'] as int? ?? 0,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      error: errorRaw is Map
          ? TestExecutionError.fromJson(Map<String, dynamic>.from(errorRaw))
          : null,
    );
  }
}
