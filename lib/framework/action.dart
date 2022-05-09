


import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';

/// payload representing an Action to do (navigateToScreen, InvokeAPI, ..)
abstract class EnsembleAction {
}

class InvokeAPIAction extends EnsembleAction {
  InvokeAPIAction({
    required this.apiName,
    this.inputs
  });
  String apiName;
  Map<String, String>? inputs;
}

class NavigateScreenAction extends EnsembleAction {
  NavigateScreenAction({
    required this.screenName,
    this.inputs
  });
  String screenName;
  Map<String, String>? inputs;
}

class ExecuteCodeAction extends EnsembleAction {
  ExecuteCodeAction({
    required this.initiator,
    required this.codeBlock,
  });

  // initiator is important when executing code, such that we can scope to *this*
  Invokable initiator;
  String codeBlock;
}


enum ActionType { invokeAPI, navigateScreen, executeCode }