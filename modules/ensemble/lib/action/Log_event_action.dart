import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/logging/log_manager.dart';
import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class LogEvent extends EnsembleAction {
  final String eventName;
  final Map<dynamic, dynamic>? parameters;
  final String logLevel;
  LogEvent(
      {super.initiator,
      required this.eventName,
      required this.logLevel,
      this.parameters});

  factory LogEvent.from({Invokable? initiator, Map? payload}) {
    payload = Utils.convertYamlToDart(payload);
    String? eventName = payload?['name'];
    if (eventName == null) {
      throw LanguageError(
          "${ActionType.logEvent.name} requires the event name");
    }

    return LogEvent(
        initiator: initiator,
        eventName: eventName,
        parameters:
            payload?['parameters'] is Map ? payload!['parameters'] : null,
        logLevel: payload?['logLevel'] ?? LogLevel.info.name);
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
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    LogManager().log(
        LogType.appAnalytics,
        stringToLogLevel(scopeManager.dataContext.eval(logLevel)),
        scopeManager.dataContext.eval(eventName),
        scopeManager.dataContext.eval(parameters) ?? {});
    return Future
        .value(); //instead of awaiting, we'll let LogManager figure it out as we don't want to block the UI
  }
}
