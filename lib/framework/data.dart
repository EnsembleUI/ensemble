import 'package:ensemble/framework/context.dart';
import 'package:ensemble/framework/view_util.dart';
import 'package:ensemble/framework/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';


/// managing a data scope within a DataScopeWidget
class ScopeManager {
  ScopeManager(this.dataContext, this.customWidgetDefinitions);

  final DataContext dataContext;
  final Map<String, YamlMap>? customWidgetDefinitions;


  /// build a widget from the item YAML
  Widget buildWidgetFromDefinition(dynamic item) {
    return buildWidget(ViewUtil.buildModel(item, customWidgetDefinitions));
  }


  /// build a widget from a given model
  Widget buildWidget(WidgetModel model) {
    // 1. create bare widget tree.
    //  - Add Invokable ID as needed and update DataContext
    //  - create a mapping of WidgetModel -> Widget
    Map<WidgetModel, Invokable> widgetMap = {};
    Widget widget = _buildBareWidget(model, widgetMap);

    // 2. execute bindings in order of dependencies
    _updateWidgetBindings(widgetMap);

    return widget;
  }

  Widget _buildBareWidget(WidgetModel model, Map<WidgetModel, Invokable> widgetMapResult) {
    Function? widgetInstance = WidgetRegistry.widgetMap[model.type];
    if (widgetInstance != null) {
      Widget widget = widgetInstance.call();

      if (widget is Invokable) {
        widgetMapResult[model] = widget as Invokable;

        // If our widget has an ID, add it to our data context
        if (model.props.containsKey('id')) {
          dataContext.addInvokableContext(
              model.props['id'],
              widget as Invokable);
        }
      }

      // build children and itemTemplate for Containers
      if (model.children != null && widget is UpdatableContainer) {
        List<Widget> children = [];
        for (WidgetModel model in model.children!) {
          children.add(_buildBareWidget(model, widgetMapResult));
        }
        (widget as UpdatableContainer).initChildren(children: children, itemTemplate: model.itemTemplate);
      }
      return widget;
    }
    return const Text("Unsupported Widget");
  }

  void _updateWidgetBindings(Map<WidgetModel, Invokable> widgetMap) {

    widgetMap.forEach((model, widget) {
      DataContext localizedContext = dataContext.clone();

      // resolve input parameters
      if (model is CustomWidgetModel) {
        if (model.parameters != null && model.inputs != null) {
          for (var param in model.parameters!) {
            if (model.inputs![param] != null) {
              localizedContext.addDataContextById(param, localizedContext.eval(model.inputs![param]));
            }
          }}
      }

      // set props and styles on the widget. At this stage the widget
      // has not been attached, so no worries about ValueNotifier
      for (String key in model.props.keys) {
        if (widget.getSettableProperties().contains(key)) {
          // actions like onTap should evaluate its expressions upon the action only
          if (key.startsWith('on')) {
            widget.setProperty(key, model.props[key]);
          } else {
            widget.setProperty(key, localizedContext.eval(model.props[key]));
          }
        }
      }
      for (String key in model.styles.keys) {
        if (widget.getSettableProperties().contains(key)) {
          widget.setProperty(key, localizedContext.eval(model.styles[key]));
        }
      }


    });
  }

  ScopeManager createChildScope() {
    return ScopeManager(dataContext.clone(), customWidgetDefinitions);
  }



  /*final EventBus _eventBus = EventBus();

  void register(Invokable destination, String modelId) {

  }

  @override
  void dispose(HasController<Controller, WidgetStateMixin> widget) {
    // TODO: implement dispose
  }



  void listen(ModelChangeEvent event) {

  }

  void dispatch(ModelChangeEvent event) {
    _eventBus.fire(event);
  }*/

}


class ModelChangeEvent {
  String modelId;
  dynamic payload;
  ModelChangeEvent(this.modelId, this.payload);
}

