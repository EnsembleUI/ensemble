import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/logging/log_manager.dart';
import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class LogEvent extends EnsembleAction {
  final String? eventName;
  final Map<dynamic, dynamic>? parameters;
  final String? provider;
  final String? operation;
  final String? userId;
  final String logLevel;

  LogEvent({
    required Invokable? initiator,
    this.eventName,
    required this.logLevel,
    required this.provider,
    this.operation,
    this.userId,
    this.parameters,
  }) : super(initiator: initiator);

  factory LogEvent.from({Invokable? initiator, Map? payload}) {
    payload = Utils.convertYamlToDart(payload);
    String? eventName = payload?['name'];
    String? operation = payload?['operation'];

    if (operation == 'logEvent' && eventName == null) {
      throw LanguageError(
          "${ActionType.logEvent.name} requires the event name");
    } else if (operation == 'setUserId' && payload?['userId'] == null) {
      throw LanguageError("${ActionType.logEvent.name} requires the user id");
    }

    return LogEvent(
      initiator: initiator,
      eventName: eventName ?? '',
      parameters: payload?['parameters'] is Map ? payload!['parameters'] : null,
      logLevel: payload?['logLevel'] ?? LogLevel.info.name,
      provider: payload?['provider'] ?? 'firebase',
      operation: payload?['operation'],
      userId: payload?['userId'],
    );
  }

  static LogLevel stringToLogLevel(String? levelStr) {
    // If the level string is null, default to LogLevel.info
    if (levelStr == null) return LogLevel.info;
    // Attempt to match the string with an enum value
    for (LogLevel level in LogLevel.values) {
      if (level.name.toLowerCase() == levelStr.toLowerCase()) {
        return level;
      }
    }
    // Default to LogLevel.info if no match is found
    return LogLevel.info;
  }

  @override
  Future<void> execute(BuildContext context, ScopeManager scopeManager) async {
    LogManager().log(
      LogType.appAnalytics,
      {
        'name': scopeManager.dataContext.eval(eventName),
        'parameters': scopeManager.dataContext.eval(parameters) ?? {},
        'logLevel': stringToLogLevel(scopeManager.dataContext.eval(logLevel)),
        'provider': scopeManager.dataContext.eval(provider),
        'operation': scopeManager.dataContext.eval(operation),
        'userId': scopeManager.dataContext.eval(userId),
      },
    );
    // Instead of awaiting, we'll let LogManager figure it out as we don't want to block the UI
  }
}
