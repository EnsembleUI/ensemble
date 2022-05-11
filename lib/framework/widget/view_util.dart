

import 'package:ensemble/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class ViewUtil {

  ///convert a YAML representing a widget to a WidgetModel
  static WidgetModel buildModel(dynamic item, Map<String, YamlMap>? customWidgetMap) {
    String? widgetType;
    YamlMap? payload;

    bool isCustomWidget = false;
    Map<String, dynamic>? customWidgetInputs;
    List<String>? customWidgetParameters;

    // name only e.g Spacer
    if (item is String) {
      widgetType = item;
    } else if (item is YamlMap) {
      widgetType = item.keys.first.toString();
      if (item[widgetType] is YamlMap) {
        payload = item[widgetType];
      }
    }

    // if this is a custom widget
    if (customWidgetMap != null && customWidgetMap[widgetType] != null) {
      isCustomWidget = true;
      // payload if exists here is a key/value pairs
      if (payload != null) {
        customWidgetInputs = {};
        payload.forEach((key, value) {
          customWidgetInputs![key] = value;
        });
      }

      // overwrite the payload & widgetType since custom widget defines their definition separately
      payload = customWidgetMap[widgetType];
      widgetType = payload!['type'];

      // see if the definition declare any parameters
      if (payload['parameters'] is YamlList) {
        customWidgetParameters = [];
        for (dynamic param in payload['parameters']) {
          customWidgetParameters.add(param.toString());
        }
      }

    }

    if (widgetType == null) {
      throw LanguageError('Invalid widget definition.', recovery: 'Widget type is required');
    }

    // Let's build the model now
    // no payload, simple widget e.g Spacer or Spacer:
    if (payload == null) {
      return WidgetModel(widgetType, {}, {});
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
          itemTemplate = ItemTemplate(
              value['data'],
              value['name'],
              value['template']);
        } else {
          props[key] = value;
        }
      }
    });

    if (isCustomWidget) {
      return CustomWidgetModel(
          widgetType,
          styles,
          props,
          children: children,
          itemTemplate: itemTemplate,
          parameters: customWidgetParameters,
          inputs: customWidgetInputs);

    } else {
      return WidgetModel(
          widgetType,
          styles,
          props,
          children: children,
          itemTemplate: itemTemplate);
    }
  }

  static List<WidgetModel> buildModels(YamlList items, Map<String, YamlMap>? customWidgetMap) {
    List<WidgetModel> rtn = [];
    for (dynamic item in items) {
      rtn.add(buildModel(item, customWidgetMap));
    }
    return rtn;
  }


  static Widget buildBareWidget(ScopeNode scopeNode, WidgetModel model, Map<WidgetModel, ModelPayload> modelMap) {

    Function? widgetInstance = WidgetRegistry.widgetMap[model.type];
    if (widgetInstance != null) {
      Widget w = widgetInstance.call();
      ScopeManager currentScope = scopeNode.scope;



      // save to the modelMap for later binding processing
      if (model is CustomWidgetModel) {
        currentScope = scopeNode.scope.createChildScope();
        scopeNode.addChild(ScopeNode(currentScope));
      }

      modelMap[model] = ModelPayload(w, currentScope);

      // If our widget has an ID, add it to our data context
      String? id = model.props['id']?.toString();
      if (id != null && w is Invokable) {
        (w as Invokable).id = id;
        currentScope.dataContext.addInvokableContext(id, (w as Invokable));
      }


      // build children and save the reference to the modelMap
      if (w is UpdatableContainer) {
        List<Widget>? children;
        if (model.children != null) {
          children = [];
          for (WidgetModel model in model.children!) {
            children.add(buildBareWidget(ScopeNode(currentScope), model, modelMap));
          }
          modelMap[model]!.children = children;
        }
      }
      return model is CustomWidgetModel ?
          DataScopeWidget(scopeManager: currentScope, child: w) :
          w;
    }
    return const Text("Unsupported Widget");
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