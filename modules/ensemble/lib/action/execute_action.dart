import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

/// Execute a named reusable Action defined under the page-level `Actions:` block and in the app's `actions` directory.
class ExecuteActionAction extends EnsembleAction {
  ExecuteActionAction({super.initiator, required this.name, this.rawInputs});

  final String name;
  final Map<String, dynamic>? rawInputs;

  factory ExecuteActionAction.fromYaml({Invokable? initiator, Map? payload}) {
    if (payload == null) {
      throw LanguageError(
          "${ActionType.executeAction.name} requires a payload with 'name'.");
    }

    final String? name = Utils.optionalString(payload['name']);
    if (name == null || name.isEmpty) {
      throw LanguageError(
          "${ActionType.executeAction.name} requires a non-empty 'name'.");
    }

    final Map<String, dynamic>? inputs =
        Utils.getMap(payload['inputs'])?.cast<String, dynamic>();

    return ExecuteActionAction(
      initiator: initiator,
      name: name,
      rawInputs: inputs,
    );
  }

  @override
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    final Map<String, YamlMap>? actionsMap = scopeManager.pageData.actionsMap;
    if (actionsMap == null || actionsMap.isEmpty) {
      throw LanguageError(
          "No reusable Actions are available in this app. Cannot execute '$name'.");
    }

    final YamlMap? definition = actionsMap[name];
    if (definition == null) {
      throw LanguageError(
          "Reusable Action '$name' is not defined in this app or page.");
    }

    // Extract the parameter list from the reusable Action definition.
    final List<String> parameters = [];
    final dynamic inputsNode = definition['inputs'];
    if (inputsNode is YamlList) {
      for (final dynamic input in inputsNode) {
        if (input != null) {
          parameters.add(input.toString());
        }
      }
    }

    // Build a child scope so parameter values are available as variables
    final ScopeManager childScope = scopeManager.createChildScope();

    final Map<String, dynamic> callInputs = rawInputs ?? const {};
    for (final String param in parameters) {
      if (callInputs.containsKey(param)) {
        final dynamic evaluated =
            childScope.dataContext.eval(callInputs[param]);
        childScope.dataContext.addDataContextById(param, evaluated);
      }
    }

    // Now resolve and execute the inner Action tree.
    final dynamic bodyNode = definition['body'];
    if (bodyNode == null) {
      throw LanguageError(
          "Action '$name' must define a 'body' payload to run.");
    }

    final EnsembleAction? innerAction =
        EnsembleAction.from(Utils.getYamlMap(bodyNode));
    if (innerAction == null) {
      throw LanguageError("Action '$name' contains an invalid 'body' payload.");
    }

    return ScreenController()
        .executeActionWithScope(context, childScope, innerAction);
  }
}
