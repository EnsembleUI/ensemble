import 'dart:async';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';


/// ScopeManager handles all data/view relative to a Scope.
/// A page can have multiple nested scopes, each with its own DataContext.
/// ScopeManager also have reference to the data at the page level.
class ScopeManager extends IsScopeManager with ViewBuilder, PageEventManager {
  ScopeManager(this._dataContext, this.pageData);

  final DataContext _dataContext;
  final PageData pageData;

  @override
  Map<String, YamlMap>? get customWidgetDefinitions => pageData.customWidgetDefinitions;

  @override
  DataContext get dataContext => _dataContext;


  /// create a copy of the parent's data scope
  ScopeManager createChildScope() {
    return ScopeManager(dataContext.clone(), pageData);
  }

}


abstract class IsScopeManager {
  DataContext get dataContext;
  Map<String, YamlMap>? get customWidgetDefinitions;
}



/// View Helper to build our widgets from within a ScopeManager
mixin ViewBuilder on IsScopeManager {

  /// build a widget from the item YAML
  Widget buildWidgetFromDefinition(dynamic item) {
    return buildWidget(ViewUtil.buildModel(item, customWidgetDefinitions));
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
}


mixin PageEventManager on IsScopeManager {

  // TODO: need to be unique per page
  final EventBus _eventBus = EventBus();

  void listen(String modelId, Function callback, {String? property}) {
    StreamSubscription subscription = _eventBus.on<ModelChangeEvent>().listen((event) {
      if (event.modelId == modelId) {
        callback(event);
      }
    });
  }

  void dispatch(ModelChangeEvent event) {
    _eventBus.fire(event);
  }


  void disposeWidget(HasController<Controller, WidgetStateMixin> widget) {
    // TODO: implement dispose
  }








}


class ModelChangeEvent {
  String modelId;
  String? property;
  dynamic payload;
  ModelChangeEvent(this.modelId, this.payload, {this.property});
}


/// data for the current View. Every Ensemble page will have
/// at least one View, each will have a PageData
class PageData {
  PageData({
    required this.pageName,
    required this.datasourceMap,
    //required DataContext eContext,
    this.customWidgetDefinitions,
    this.pageStyles,
    this.pageTitle,
    this.pageType,
    this.apiMap
  }) {
    //_eContext = eContext;
  }

  final String? pageTitle;

  final PageType? pageType;

  // unique page name
  final String pageName;

  final Map<String, dynamic>? pageStyles;

  // store the data sources (e.g API result) and their callbacks
  final Map<String, ActionResponse> datasourceMap;

  // store the raw definition of the SubView (to be accessed by itemTemplates)
  final Map<String, YamlMap>? customWidgetDefinitions;

  // arguments passed into this page
  //late final DataContext _eContext;

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