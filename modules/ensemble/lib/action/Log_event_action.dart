import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/logging/log_manager.dart';
import 'package:ensemble/framework/logging/log_provider.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class TrackEvent extends EnsembleAction {
  final String eventName;
  final Map<dynamic, dynamic>? parameters;
  final String logLevel;

  TrackEvent({
    required Invokable? initiator,
    required this.eventName,
    required this.logLevel,
    this.parameters,
  }) : super(initiator: initiator);

  factory TrackEvent.from({Invokable? initiator, Map? payload}) {
    payload = Utils.convertYamlToDart(payload);
    String? eventName = payload?['name'];
    if (eventName == null) {
      throw LanguageError(
          "${ActionType.trackEvent.name} requires the event name");
    }

    return TrackEvent(
      initiator: initiator,
      eventName: eventName,
      parameters: payload?['parameters'] is Map ? payload!['parameters'] : null,
      logLevel: payload?['logLevel'] ?? LogLevel.info.name,
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
      stringToLogLevel(scopeManager.dataContext.eval(logLevel)),
      scopeManager.dataContext.eval(eventName),
      scopeManager.dataContext.eval(parameters) ?? {},
    );
    // Instead of awaiting, we'll let LogManager figure it out as we don't want to block the UI
  }
}
