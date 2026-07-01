import 'package:ensemble/ensemble.dart';
import 'package:flutter/foundation.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/definition_providers/provider.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

/// Utilities for reusable Action definitions that support scoped
/// [Import], [Global], and [API] blocks (similar to custom widgets).
/// Utilities for resolving action imports, scoped APIs, and event handler payloads.
class ActionScopeUtil {
  static const List<String> _fileLevelKeys = [
    PageModel.importToken,
    'Global',
    'API',
  ];

  /// Merge file-level [Import], [Global], and [API] into the Action definition.
  static YamlMap? mergeActionFileContent(Map actionContent) {
    final dynamic actionRoot = actionContent['Action'];
    if (actionRoot is! Map) {
      return null;
    }

    final Map<dynamic, dynamic> merged = Map.from(actionRoot);
    for (final key in _fileLevelKeys) {
      if (actionContent[key] != null) {
        merged[key] = actionContent[key];
      }
    }
    return YamlMap.wrap(merged);
  }

  /// Normalize a single action definition from any provider format.
  /// Handles file-level [Action] wrappers with sibling [Import]/[Global]/[API]
  /// blocks, as well as already-flattened definitions.
  static YamlMap? normalizeActionDefinition(dynamic definition) {
    YamlMap? yaml;
    if (definition is YamlMap) {
      yaml = definition;
    } else if (definition is Map) {
      yaml = YamlMap.wrap(definition);
    } else if (definition is String && definition.isNotEmpty) {
      final parsed = loadYaml(definition);
      if (parsed is YamlMap) {
        yaml = parsed;
      }
    }
    if (yaml == null) {
      return null;
    }

    if (yaml['Action'] is Map) {
      return mergeActionFileContent(yaml) ?? yaml;
    }
    return yaml;
  }

  /// Normalize all entries in an [Actions] resources map.
  static Map<String, YamlMap> normalizeActionsMap(Map actionsRaw) {
    final Map<String, YamlMap> normalized = {};
    actionsRaw.forEach((key, value) {
      final YamlMap? action = normalizeActionDefinition(value);
      if (action != null) {
        normalized[key.toString()] = action;
      }
    });
    return normalized;
  }

  /// Normalize the [Actions] entry inside a resources map, if present.
  static Map? normalizeResources(Map? resources) {
    if (resources == null) {
      return null;
    }
    final dynamic actions = resources[ResourceArtifactEntry.Actions.name];
    if (actions is! Map || actions.isEmpty) {
      return resources;
    }
    final Map normalized = Map.from(resources);
    normalized[ResourceArtifactEntry.Actions.name] =
        normalizeActionsMap(actions);
    return normalized;
  }

  /// Merge file-level keys when an [Action] wrapper is present in CDN content.
  static YamlMap mergeCdnActionContent(YamlMap yaml, dynamic actionRoot) {
    return normalizeActionDefinition(yaml) ?? YamlMap();
  }

  /// Save page-level API entries that a reusable action will override via
  /// [createChildScope]. Call before [prepareScope] and pair with
  /// [restorePageApisAfterAction] in a `finally` block.
  @visibleForTesting
  static Map<String, YamlMap?>? snapshotPageApisForAction(
      ScopeManager parentScope, Map<String, YamlMap>? actionApiMap) {
    if (actionApiMap == null || actionApiMap.isEmpty) {
      return null;
    }

    final pageApiMap = parentScope.pageData.apiMap ??= {};
    final snapshot = <String, YamlMap?>{};
    for (final key in actionApiMap.keys) {
      snapshot[key] = pageApiMap.containsKey(key) ? pageApiMap[key] : null;
    }
    return snapshot;
  }

  /// Restores page API definitions after a reusable action finishes.
  @visibleForTesting
  static void restorePageApisAfterAction(
      ScopeManager parentScope, Map<String, YamlMap?>? snapshot) {
    if (snapshot == null || snapshot.isEmpty) {
      return;
    }

    final pageApiMap = parentScope.pageData.apiMap;
    if (pageApiMap == null) {
      return;
    }

    snapshot.forEach((key, original) {
      if (original == null) {
        pageApiMap.remove(key);
      } else {
        pageApiMap[key] = original;
      }
    });
  }

  static Map<String, YamlMap>? parseApiMap(YamlMap definition) {
    final dynamic apiNode = definition['API'];
    if (apiNode is! YamlMap) {
      return null;
    }
    final Map<String, YamlMap> apiMap = {};
    apiNode.forEach((key, value) {
      if (value is YamlMap) {
        apiMap[key.toString()] = value;
      }
    });
    return apiMap.isEmpty ? null : apiMap;
  }

  static Map<String, EnsembleEvent> parseEventParams(YamlMap definition) {
    final Map<String, EnsembleEvent> eventParams = {};
    final dynamic eventsNode = definition['events'];
    if (eventsNode is Map) {
      eventsNode.forEach((key, value) {
        eventParams[key.toString()] = EnsembleEvent.fromYaml(
            key.toString(), value is YamlMap ? value : null);
      });
    }
    return eventParams;
  }

  static Map<String, EnsembleAction?> parseEventHandlers(Map? eventsPayload) {
    final Map<String, EnsembleAction?> eventHandlers = {};
    if (eventsPayload is Map) {
      eventsPayload.forEach((key, value) {
        eventHandlers[key.toString()] = EnsembleAction.from(value);
      });
    }
    return eventHandlers;
  }

  /// Register caller-provided event handlers on the action scope.
  /// Handlers execute in the parent (caller) scope, matching custom widget behavior.
  static void registerEventHandlers({
    required ScopeManager parentScope,
    required ScopeManager actionScope,
    required Map<String, EnsembleAction?> eventHandlers,
  }) {
    eventHandlers.forEach((eventName, action) {
      if (action == null) {
        return;
      }
      final handler = EnsembleEventHandler(parentScope, action);
      actionScope.dataContext.addDataContextById(eventName, handler);
    });
  }

  static ({String? code, SourceSpan? span}) parseGlobalCode(YamlMap definition) {
    final YamlNode? globalCodeNode = definition.nodes['Global'];
    if (globalCodeNode == null) {
      return (code: null, span: null);
    }
    return (
      code: Utils.optionalString(globalCodeNode.value),
      span: ViewUtil.getDefinition(globalCodeNode),
    );
  }

  /// Prepare a child scope with imports, APIs, global code, and input parameters.
  static ScopeManager prepareScope({
    required ScopeManager parentScope,
    required YamlMap definition,
    required List<String> parameters,
    Map<String, dynamic> callInputs = const {},
    Map<String, EnsembleAction?> eventHandlers = const {},
  }) {
    final importedCode = definition[PageModel.importToken] != null
        ? Ensemble().getConfig()?.processImports(definition[PageModel.importToken])
        : null;
    final apiMap = parseApiMap(definition);

    final ScopeManager childScope = parentScope.createChildScope(
      childImportedCode: importedCode,
      mergedApiMap: apiMap,
    );

    apiMap?.forEach((key, value) {
      if (!childScope.dataContext.hasContext(key)) {
        childScope.dataContext.addInvokableContext(key, APIResponse());
      }
    });

    for (final String param in parameters) {
      if (callInputs.containsKey(param)) {
        final dynamic evaluated = childScope.dataContext.eval(callInputs[param]);
        childScope.dataContext.addDataContextById(param, evaluated);
      }
    }

    final global = parseGlobalCode(definition);
    if (global.code != null && global.span != null) {
      childScope.dataContext.evalCode(global.code!, global.span!);
    }

    if (eventHandlers.isNotEmpty) {
      registerEventHandlers(
        parentScope: parentScope,
        actionScope: childScope,
        eventHandlers: eventHandlers,
      );
    }

    return childScope;
  }
}
