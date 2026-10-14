import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/tool_response.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/widgets.dart';

/// Responds to the active model tool call.
class RespondToToolAction extends EnsembleAction {
  RespondToToolAction({
    super.initiator,
    required this.status,
    this.callId,
    this.data,
    this.error,
  });

  final dynamic status;
  final dynamic callId;
  final dynamic data;
  final dynamic error;

  factory RespondToToolAction.fromYaml({
    Invokable? initiator,
    Map? payload,
  }) {
    if (payload == null || payload['status'] == null) {
      throw LanguageError(
          "${ActionType.respondToTool.name} requires a 'status'.");
    }
    return RespondToToolAction(
      initiator: initiator,
      status: payload['status'],
      callId: payload['callId'],
      data: payload['data'],
      error: payload['error'],
    );
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    final evaluatedStatus =
        Utils.optionalString(scopeManager.dataContext.eval(status));
    const supportedStatuses = {'approved', 'success', 'error', 'cancelled'};
    if (evaluatedStatus == null ||
        !supportedStatuses.contains(evaluatedStatus)) {
      throw LanguageError(
          '${ActionType.respondToTool.name}.status must be approved, success, error, or cancelled.');
    }

    var evaluatedCallId =
        Utils.optionalString(scopeManager.dataContext.eval(callId));
    final toolContext = scopeManager.dataContext.getContextById('tool');
    if (evaluatedCallId == null && toolContext is EnsembleToolCallContext) {
      evaluatedCallId = toolContext.callId;
    } else if (evaluatedCallId == null && toolContext is Map) {
      evaluatedCallId = Utils.optionalString(toolContext['callId']);
    }

    if (evaluatedCallId == null || evaluatedCallId.isEmpty) {
      throw LanguageError(
          '${ActionType.respondToTool.name} must run inside an active tool scope.');
    }

    await EnsembleToolResponseDispatcher.instance.tryRespond(
      EnsembleToolResponse(
        callId: evaluatedCallId,
        status: evaluatedStatus,
        data: scopeManager.dataContext.eval(data),
        error: scopeManager.dataContext.eval(error),
      ),
    );
  }
}
