import 'dart:async';
import 'dart:developer';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';


/// ScopeManager handles all data/view relative to a Scope. It also has a
/// reference to the page-level PageData.
/// This class is a composite:
///  - ViewBuilder: helper class with building widgets
///  - PageBindingManager: managing event bindings at the page level
class ScopeManager extends IsScopeManager with ViewBuilder, PageBindingManager {
  ScopeManager(this._dataContext, this.pageData);

  final DataContext _dataContext;
  final PageData pageData;

  @override
  Map<String, YamlMap>? get customViewDefinitions => pageData.customViewDefinitions;

  @override
  DataContext get dataContext => _dataContext;

  @override
  EventBus get eventBus => pageData.eventBus;

  @override
  // TODO: implement listenerMap
  Map<Invokable, Map<int, StreamSubscription>> get listenerMap => pageData.listenerMap;

  /// create a copy of the parent's data scope
  @override
  ScopeManager createChildScope() {
    return ScopeManager(dataContext.clone(), pageData);
  }

}


abstract class IsScopeManager {
  DataContext get dataContext;
  Map<String, YamlMap>? get customViewDefinitions;
  EventBus get eventBus;
  Map<Invokable, Map<int, StreamSubscription>> get listenerMap;
  ScopeManager createChildScope();
}



/// View Helper to build our widgets from within a ScopeManager
mixin ViewBuilder on IsScopeManager {

  /// build a widget from the item YAML
  Widget buildWidgetFromDefinition(dynamic item) {
    return buildWidget(ViewUtil.buildModel(item, customViewDefinitions));
  }

  /// build a widget from a given model
  Widget buildWidget(WidgetModel model) {
    // 1. create bare widget tree.
    //  - Add Widget ID as needed to our DataContext
    //  - update the mapping of WidgetModel -> Widget
    Map<WidgetModel, Invokable> widgetMap = {};
    Widget widget = _buildBareWidget(model, widgetMap);

    // 2. execute bindings
    //  - TODO: detect circular dependencies so we don't have infinite loop
    _updateWidgetBindings(widgetMap);

    return widget;
  }

  /// Create a bare widget tree without setting any values on it.
  /// If we encounter a widget with ID, add it to the DataContext
  /// We also update the mapping of WidgetModel -> Widget
  Widget _buildBareWidget(WidgetModel model, Map<WidgetModel, Invokable> widgetMapResult) {
    Function? widgetInstance = WidgetRegistry.widgetMap[model.type];
    if (widgetInstance != null) {
      Widget widget = widgetInstance.call();
      if (widget is Invokable) {

        widgetMapResult[model] = widget as Invokable;

        // If our widget has an ID, add it to our data context
        if (model.props.containsKey('id')) {
          (widget as Invokable).id = model.props['id'];
          dataContext.addInvokableContext(
              model.props['id'],
              widget as Invokable);
        }
      }

      // build children and itemTemplate for Containers
      if (widget is UpdatableContainer) {
        List<Widget>? children;
        if (model.children != null) {
          children = [];
          for (WidgetModel model in model.children!) {
            children.add(_buildBareWidget(model, widgetMapResult));
          }
        }
        // evaluate the itemTemplate data as initial value
        if (model.itemTemplate != null) {
          dynamic initialValue = dataContext.eval(model.itemTemplate!.data);
          model.itemTemplate!.initialValue = initialValue;
        }

        (widget as UpdatableContainer).initChildren(children: children, itemTemplate: model.itemTemplate);
      }
      return widget;
    }
    return const Text("Unsupported Widget");
  }

  /// iterate through and set/evaluate the widget's properties/styles/...
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
            setPropertyAndRegisterBinding(localizedContext, widget, key, model.props[key]);
          }
        }
      }
      for (String key in model.styles.keys) {
        if (widget.getSettableProperties().contains(key)) {
          setPropertyAndRegisterBinding(localizedContext, widget, key, model.styles[key]);
        }
      }


    });
  }

  /// call widget.setProperty to update its value.
  /// If the value is an expression of valid binding, we
  /// will register to listen for changes
  void setPropertyAndRegisterBinding(DataContext dataContext, Invokable widget, String key, dynamic value) {
    if (value is String && Utils.hasExpression(value)) {
      // listen for binding changes
      (this as PageBindingManager).registerBindingListener(
          BindingDestination(widget, key),
          value);
      // evaluate the binding as the initial value
      value = dataContext.eval(value);
    }
    widget.setProperty(key, value);

  }
}

/// Binding Destination represents the left predicate of a binding expression
/// myText.text: $(myTextInput.value)
/// myText.text: $(myAPI.body.result.status)
class BindingDestination {
  BindingDestination(this.widget, this.setterProperty);

  Invokable widget;
  String setterProperty;
}
/// Binding source represents the binding expression
/// $(myText.text)
/// $(myAPI.body.result.status)
class BindingSource {
  BindingSource(this.model, this.modelId, this.property);

  Invokable model;
  String modelId;
  String property;
}

/// managing binding at the Page level.
/// It does this by tapping into the page-level's PageData
mixin PageBindingManager on IsScopeManager {


  /// Evaluate a binding expression and listen for changes.
  /// Calling this multiple times is safe as we remove the matching listeners before adding.
  /// Upon changes, execute setProperty() on the destination's Invokable
  /// The expression can be a mix of variable and text e.g Hello $(first) $(last)
  void registerBindingListener(BindingDestination bindingDestination, String rawBinding) {
    List<String> expressions = Utils.getExpressionsFromString(rawBinding);

    // we re-evaluate the entire raw binding upon any changes to any variables
    for (var expression in expressions) {
      listen(expression, me: bindingDestination.widget, onDataChange: (ModelChangeEvent event) {
        // payload only have changes to a variable, but we have to evaluate the entire expression
        // e.g Hello $(firstName.value) $(lastName.value)
        dynamic updatedValue = dataContext.eval(rawBinding);
        bindingDestination.widget.setProperty(bindingDestination.setterProperty, updatedValue);
      });
    }
  }


  /// listen for changes on the bindingExpression and invoke onDataChange() callback.
  /// Multiple calls to this is safe as we remove the existing listeners before adding.
  /// [bindingExpression] a valid binding expression in the form of getter e.g $(myText.text)
  /// [me] the widget that initiated this listener. We need this to properly remove
  /// all listeners when the widget is disposed.
  /// @return true if we are able to bind and listen to the expression.
  bool listen(
      String bindingExpression, {
        required Invokable me,
        required Function onDataChange
      }) {

    BindingSource? bindingSource = parseExpression(bindingExpression);
    if (bindingSource != null) {
      // create a unique key to reference our listener. We used this to save
      // the listeners for clean up
      int? hash;
      // for API we simply say notify me when API result changes, so the property
      // after the API name won't matter here
      if (bindingSource.model is APIResponse) {
        hash = getHash(sourceId: bindingSource.modelId);
      }
      // For now support Widget's getters() only e.g $(myText.value)
      else if (bindingSource.model is HasController && !bindingSource.property.contains('.')) {
        // clean up existing listeners
        hash = getHash(sourceId: bindingSource.modelId, sourceProperty: bindingSource.property);
      }

      if (hash != null) {
        // clean up existing listener with the same signature
        if (listenerMap[me]?[hash] != null) {
          log("Binding(remove duplicate): ${me.id}-${bindingSource.modelId}-${bindingSource.property}");
          listenerMap[me]![hash]!.cancel();
        }
        StreamSubscription subscription = eventBus.on<ModelChangeEvent>()
            .listen((event) {
          log("EventBus ${eventBus.hashCode} listening: $event");
          if (event.modelId == bindingSource.modelId &&
              (event.property == null || event.property == bindingSource.property)) {
            onDataChange(event);
          }
        });

        // save to the listener map so we can remove later
        if (listenerMap[me] == null) {
          listenerMap[me] = {};
        }
        //log("Binding: Adding ${me.id}-${bindingSource.modelId}-${bindingSource.property}");
        listenerMap[me]![hash] = subscription;
        //log("All Bindings:${listenerMap.toString()} ");

        return true;
      }
    }
    return false;

  }

  /// parse a valid expression into a BindingSource object
  /// $(myText.text)
  BindingSource? parseExpression(String expression) {
    if (Utils.isExpression(expression)) {
      String variable = expression.substring(2, expression.length - 1);
      int dotIndex = variable.indexOf('.');
      if (dotIndex != -1) {
        String modelId = variable.substring(0, dotIndex);
        String property = variable.substring(dotIndex + 1);
        dynamic model = dataContext.getContextById(modelId);
        if (model is Invokable) {
          return BindingSource(model, modelId, property);
        }
      }
    }
    return null;
  }

  void dispatch(ModelChangeEvent event) {
    log("EventBus ${eventBus.hashCode} firing $event");
    eventBus.fire(event);
  }

  /// upon widget being disposed, we need to remove all listeners associated with it
  void disposeWidget(Invokable widget) {
    if (listenerMap[widget] != null) {
      for (StreamSubscription listener in listenerMap[widget]!.values) {
        listener.cancel();
      }
      log("Binding -: Disposing ${widget}(${widget.id ?? ''}). Removing ${listenerMap[widget]!.length} listeners");
      listenerMap.remove(widget);
    }
  }

  /// unique but repeatable hash (within the same session) of the provided keys
  int getHash({String? destinationSetter, required String sourceId, String? sourceProperty}) {
    return Object.hash(destinationSetter, sourceId, sourceProperty);
  }

  /// print a map of the current listeners on this scope
  void debugListenerMap() {
    listenerMap.forEach((widget, map) {
      log('----listeners----');
      log('$widget has ${map.length} listeners');
      log('----- Event bus ${eventBus.hashCode} destroyed ------');
    });

  }




}


class ModelChangeEvent {
  String modelId;
  String? property;
  dynamic payload;
  ModelChangeEvent(this.modelId, this.payload, {this.property});

  @override
  String toString() {
    return "ModelChangeEvent($modelId, $property)";
  }
}


/// data for the current Page.
class PageData {
  PageData({
    required this.datasourceMap,
    this.customViewDefinitions,
    this.apiMap
  }) {
    log("EventBus ${eventBus.hashCode} created");
  }

  // we'll have 1 EventBus and listenerMap for each Page
  final EventBus eventBus = EventBus();
  final Map<Invokable, Map<int, StreamSubscription>> listenerMap = {};

  // store the data sources (e.g API result) and their callbacks
  @Deprecated('Use EventBus instead')
  final Map<String, ActionResponse> datasourceMap;

  // store the raw definition of the SubView (to be accessed by itemTemplates)
  final Map<String, YamlMap>? customViewDefinitions;

  // API model mapping
  Map<String, YamlMap>? apiMap;

  /// everytime we call this, we make sure any populated API result will have its updated values here
  /*DataContext getEnsembleContext() {
    for (var element in datasourceMap.values) {
      if (element._resultData != null) {
        _eContext.addDataContext(element._resultData!);
      }
    }
    return _eContext;
  }*/




}