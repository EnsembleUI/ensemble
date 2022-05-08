


import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';

/// payload representing an Action to do (navigateToScreen, InvokeAPI, ..)
class EnsembleAction {
  EnsembleAction(this.actionType, {
    this.actionName,
    this.inputs,
    this.codeBlock,
    this.initiator
  });

  ActionType actionType;
  String? actionName;
  Map<String, String>? inputs;
  String? codeBlock;

  // initiator is important when executing code, such that we can scope to *this*
  Invokable? initiator;
}


enum ActionType { invokeAPI, navigateScreen, executeCode }