import 'package:ensemble/action/action_scope_util.dart';
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
  ExecuteActionAction({
    super.initiator,
    required this.name,
    this.rawInputs,
    this.eventHandlers = const {},
  });

  final String name;
  final Map<String, dynamic>? rawInputs;
  final Map<String, EnsembleAction?> eventHandlers;

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
      eventHandlers: ActionScopeUtil.parseEventHandlers(
          Utils.getMap(payload['events'])),
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

    final Map<String, YamlMap>? actionApiMap =
        ActionScopeUtil.parseApiMap(definition);
    final Map<String, YamlMap?>? apiSnapshot =
        ActionScopeUtil.snapshotPageApisForAction(scopeManager, actionApiMap);

    try {
      // Build a child scope with optional Import, API, Global, and input parameters
      final ScopeManager childScope = ActionScopeUtil.prepareScope(
        parentScope: scopeManager,
        definition: definition,
        parameters: parameters,
        callInputs: rawInputs ?? const {},
        eventHandlers: eventHandlers,
      );

      // Now resolve and execute the inner Action tree.
      final dynamic bodyNode = definition['body'];
      if (bodyNode == null) {
        throw LanguageError(
            "Action '$name' must define a 'body' payload to run.");
      }

      final EnsembleAction? innerAction =
          EnsembleAction.from(Utils.getYamlMap(bodyNode));
      if (innerAction == null) {
        throw LanguageError(
            "Action '$name' contains an invalid 'body' payload.");
      }

      return await ScreenController()
          .executeActionWithScope(context, childScope, innerAction);
    } finally {
      ActionScopeUtil.restorePageApisAfterAction(scopeManager, apiSnapshot);
    }
  }
}
