


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
  final Map<String, String>? inputs;
  EnsembleAction? onResponse;
  EnsembleAction? onError;
}

class NavigateScreenAction extends EnsembleAction {
  NavigateScreenAction({
    Invokable? initiator,
    required this.screenName,
    this.inputs
  }) : super(initiator: initiator);

  String screenName;
  Map<String, String>? inputs;
}

class ExecuteCodeAction extends EnsembleAction {
  ExecuteCodeAction({
    Invokable? initiator,
    required this.codeBlock,
  }) : super(initiator: initiator);

  String codeBlock;
}


enum ActionType { invokeAPI, navigateScreen, executeCode }