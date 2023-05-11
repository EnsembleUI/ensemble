import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/custom_view.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/gesture_detector.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';
import 'package:source_span/source_span.dart';

class ViewUtil {
  static bool isViewModel(dynamic item, Map<String, dynamic>? customWidgetMap) {
    if (item != null) {
      return customWidgetMap?[item.toString()] != null || item is YamlMap;
    }
    return false;
  }

  /// convert a YamlMap to Map
  static Map<String, dynamic>? getMap(dynamic rawMap) {
    Map<String, dynamic>? rtn;
    if (rawMap is YamlMap) {
      rtn = {};
      rawMap.forEach((key, value) {
        rtn![key] = value;
      });
    }
    return rtn;
  }

  static SourceSpan optDefinition(YamlNode? node) {
    if (node == null) {
      return SourceSpanBase(SourceLocationBase(0), SourceLocationBase(0), '');
    }
    return getDefinition(node!);
  }

  static SourceSpan getDefinition(YamlNode node) {
    //we are doing a deep copy instead of re-using the object to make sure that we don't cause memory leaks
    return SourceSpanBase(
        SourceLocationBase(node.span.start.offset,
            sourceUrl: node.span.start.sourceUrl,
            line: node.span.start.line,
            column: node.span.start.column),
        SourceLocationBase(node.span.end.offset,
            sourceUrl: node.span.end.sourceUrl,
            line: node.span.end.line,
            column: node.span.end.column),
        node.span.text);
  }

  ///convert a YAML representing a widget to a WidgetModel
  static WidgetModel buildModel(
      dynamic item, Map<String, dynamic>? customWidgetMap) {
    String? widgetType;
    YamlMap? payload;
    SourceSpan def =
        SourceSpanBase(SourceLocationBase(0), SourceLocationBase(0), '');
    // name only e.g Spacer
    if (item is String) {
      widgetType = item;
    } else if (item is YamlMap) {
      widgetType = item.keys.first.toString();
      if (item[widgetType] is YamlMap) {
        payload = item[widgetType];
      }
      def = getDefinition(item);
    } else if (item is MapEntry) {
      widgetType = item.key as String;
      if (item.value is YamlMap) {
        payload = item.value;
        def = getDefinition(item.value);
      } else if (item.value is String) {
        widgetType = item.value;
      }
    }

    // if this is a custom widget
    if (customWidgetMap?[widgetType] != null) {
      WidgetModel? customModel = buildCustomModel(
          payload, customWidgetMap![widgetType]!, customWidgetMap);
      if (customModel == null) {
        throw LanguageError("Unable to build the Custom Widget");
      }
      return customModel;
    }

    if (widgetType == null) {
      throw LanguageError('Invalid widget definition.',
          recovery: 'Please provide a valid widget.');
    }

    // Let's build the model now
    // no payload, simple widget e.g Spacer or Spacer:
    if (payload == null) {
      return WidgetModel(def, widgetType, {}, {});
    }

    List<WidgetModel>? children;
    ItemTemplate? itemTemplate;
    Map<String, dynamic> props = {};
    Map<String, dynamic> styles = {};

    payload.forEach((key, value) {
      if (value != null) {
        if (key == 'styles' && value is YamlMap) {
          value.forEach((styleKey, styleValue) {
            styles[styleKey] = styleValue;
          });
        } else if (key == 'children' && value is YamlList) {
          children = ViewUtil.buildModels(value, customWidgetMap);
        } else if (key == "item-template" && value is YamlMap) {
          itemTemplate =
              ItemTemplate(value['data'], value['name'], value['template']);
        } else {
          props[key] = value;
        }
      }
    });

    return WidgetModel(def, widgetType, styles, props,
        children: children, itemTemplate: itemTemplate);
  }

  static WidgetModel? buildCustomModel(YamlMap? callerPayload,
      dynamic viewDefinition, Map<String, dynamic> customWidgetMap) {
    // the custom definition may just have another widget name (with zero other information)
    if (viewDefinition is String) {
      return buildModel(viewDefinition, customWidgetMap);
    }
    // caller payload may comprise of an ID and input payload key/value pairs. Ignore ID for now
    Map<String, dynamic> inputPayload = {};
    if (callerPayload?['inputs'] is YamlMap) {
      callerPayload!['inputs'].forEach((key, value) {
        inputPayload[key] = value;
      });
    }

    WidgetModel? widgetModel;
    Map<String, dynamic> props = {};
    List<String> inputParams = [];
    for (MapEntry entry in (viewDefinition as YamlMap).entries) {
      // see if the custom widget actually declare any input parameters
      if (entry.key == 'inputs' && entry.value is YamlList) {
        for (var input in entry.value) {
          inputParams.add(input.toString());
        }
      }
      // extract onLoad and other properties at the root of the Custom Widget
      else if (entry.key == 'onLoad') {
        props[entry.key] = entry.value;
      } else if (entry.key == 'body') {
        widgetModel = ViewUtil.buildModel(entry.value, customWidgetMap);
      }
      // backward compatible - find the first widget model
      else {
        // if a regular widget or custom widget
        if (WidgetRegistry.widgetMap[entry.key] != null ||
            customWidgetMap[entry.key] != null) {
          widgetModel = ViewUtil.buildModel(entry, customWidgetMap);

          // there should only be 1 widget model
          break;
        }
      }
    }

    if (widgetModel == null) {
      throw LanguageError("Custom Widget requires a child widget");
    }

    return CustomWidgetModel(widgetModel, props,
        inputs: inputPayload, parameters: inputParams);
  }

  static List<WidgetModel> buildModels(
      YamlList items, Map<String, dynamic>? customWidgetMap) {
    List<WidgetModel> rtn = [];
    for (dynamic item in items) {
      rtn.add(buildModel(item, customWidgetMap));
    }
    return rtn;
  }

  static Widget buildBareCustomWidget(ScopeNode scopeNode,
      CustomWidgetModel customModel, Map<WidgetModel, ModelPayload> modelMap) {
    // create a new Scope (for our custom widget) and add to the parent
    ScopeManager customScope = scopeNode.scope.createChildScope();
    ScopeNode customScopeNode = ScopeNode(customScope);
    scopeNode.addChild(customScopeNode);

    // build the root child widget
    Widget rootWidget =
        buildBareWidget(customScopeNode, customModel.getModel(), modelMap);

    Widget customWidget = CustomView(
        childWidget: rootWidget,
        parameters: customModel.parameters,
        scopeManager: customScope,
        viewBehavior: customModel.getViewBehavior());
    modelMap[customModel] = ModelPayload(customWidget, customScope);

    return DataScopeWidget(scopeManager: customScope, child: customWidget);
  }

  static Widget buildBareWidget(ScopeNode scopeNode, WidgetModel model,
      Map<WidgetModel, ModelPayload> modelMap) {
    if (model is CustomWidgetModel) {
      return buildBareCustomWidget(scopeNode, model, modelMap);
    }

    Function? widgetInstance = WidgetRegistry.widgetMap[model.type];
    if (widgetInstance != null) {
      Widget w = widgetInstance.call();
      ScopeManager currentScope = scopeNode.scope;

      modelMap[model] = ModelPayload(w, currentScope);

      // If our widget has an ID, add it to our data context
      String? id = model.props['id']?.toString();
      if (w is Invokable) {
        (w as Invokable).definition = model.definition;
        if (id != null) {
          (w as Invokable).id = id;
          currentScope.dataContext.addInvokableContext(id, (w as Invokable));
        }
      }

      // build children and save the reference to the modelMap
      if (w is UpdatableContainer) {
        List<Widget>? children;
        if (model.children != null) {
          children = [];
          for (WidgetModel model in model.children!) {
            //children.add(buildBareWidget(ScopeNode(currentScope), model, modelMap));
            children.add(buildBareWidget(scopeNode, model, modelMap));
          }
          modelMap[model]!.children = children;
        }
      }
      // for Custom View, we wraps it around a DataScope to separate the data context.
      // Additionally Custom View has special behavior (e.g. onLoad) that needs to be
      // processed, so wraps it in a CustomView widget
      return w;
    }
    throw LanguageError("Unsupported Widget: ${model.type}");
  }

  /// traverse the scope breath-first and propagate all data from the root down
  static void propagateScopes(ScopeNode scopeNode) {
    _traverseScopes(scopeNode, scopeNode.children);
  }

  static void _traverseScopes(ScopeNode parent, List<ScopeNode>? children) {
    if (children != null) {
      // copy over the parent data context, but skip existing keys the child has
      // the reason is child may declare the same ID, which takes precedent over
      // the variable from the parent
      for (ScopeNode child in children) {
        child.scope.dataContext.copy(parent.scope.dataContext);
      }
      for (ScopeNode child in children) {
        _traverseScopes(child, child.children);
      }
    }
  }

  static void checkValidWidget(
      List<Widget>? children, ItemTemplate? itemTemplate) {
    final isInvalid =
        children != null && children.isNotEmpty && itemTemplate != null;

    if (isInvalid) {
      throw LanguageError("You can't have both children and item-template");
    }
  }

  static List<Widget> addGesture(
      List<Widget> children, Function(int) onItemTap) {
    List<Widget> clickableWidgets = [];
    children.asMap().forEach((index, value) {
      final child = EnsembleGestureDetector(
        child: value,
        onTap: () => onItemTap(index),
      );
      clickableWidgets.add(child);
    });
    return clickableWidgets;
  }
}

class ModelPayload {
  ModelPayload(this.widget, this.scopeManager);

  final Widget widget;
  final ScopeManager scopeManager;
  List<Widget>? children;
}

/// wrapper ScopeManager as a tree node
class ScopeNode {
  ScopeNode(this.scope);

  final ScopeManager scope;
  List<ScopeNode>? children;

  addChild(ScopeNode child) {
    (children ??= []).add(child);
  }
}
