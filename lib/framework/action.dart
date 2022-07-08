


import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';

/// payload representing an Action to do (navigateToScreen, InvokeAPI, ..)
abstract class EnsembleAction {
  EnsembleAction({this.initiator});

  // initiator is an Invokable so we can scope to *this* variable
  Invokable? initiator;
}

class InvokeAPIAction extends EnsembleAction {
  InvokeAPIAction({
    Invokable? initiator,
    required this.apiName,
    this.inputs,
    this.onResponse,
    this.onError
  }) : super(initiator: initiator);

  final String apiName;
  final Map<String, dynamic>? inputs;
  EnsembleAction? onResponse;
  EnsembleAction? onError;
}

class ShowDialogAction extends EnsembleAction {
  ShowDialogAction({
    Invokable? initiator,
    required this.content,
    this.options,
    this.onDialogDismiss
  }) : super(initiator: initiator);

  final dynamic content;
  final Map<String, dynamic>? options;
  final EnsembleAction? onDialogDismiss;
}

class NavigateScreenAction extends BaseNavigateScreenAction {
  NavigateScreenAction({
    Invokable? initiator,
    required String screenName,
    Map<String, dynamic>? inputs
  }) : super(initiator: initiator, screenName: screenName, asModal: false, inputs: inputs);
}

class NavigateModalScreenAction extends BaseNavigateScreenAction {
  NavigateModalScreenAction({
    Invokable? initiator,
    required String screenName,
    Map<String, dynamic>? inputs,
    this.onModalDismiss,
    }) : super(initiator: initiator, screenName: screenName, asModal: true, inputs: inputs);

  EnsembleAction? onModalDismiss;

}

abstract class BaseNavigateScreenAction extends EnsembleAction {
  BaseNavigateScreenAction({
    Invokable? initiator,
    required this.screenName,
    required this.asModal,
    this.inputs
  }) : super(initiator: initiator);

  String screenName;
  bool asModal;
  Map<String, dynamic>? inputs;
}

class StartTimerAction extends EnsembleAction {
  StartTimerAction({
    Invokable? initiator,
    required this.onTimer,
    this.onTimerComplete,
    this.payload
  }) : super(initiator: initiator);

  final EnsembleAction onTimer;
  final EnsembleAction? onTimerComplete;
  final TimerPayload? payload;
}

class ExecuteCodeAction extends EnsembleAction {
  ExecuteCodeAction({
    Invokable? initiator,
    required this.codeBlock,
    this.onComplete
  }) : super(initiator: initiator);

  String codeBlock;
  EnsembleAction? onComplete;
}

class TimerPayload {
  TimerPayload({
    this.id,
    this.startAfter,
    required this.repeat,
    this.repeatInterval,
    this.maxTimes
  });

  final String? id;
  final int? startAfter;  // The initial delay in seconds

  final bool repeat;
  final int? repeatInterval;  // The repeat interval in seconds
  final int? maxTimes;         // how many times to trigger onTimer
}


enum ActionType { invokeAPI, navigateScreen, navigateModalScreen, showDialog, startTimer, executeCode }