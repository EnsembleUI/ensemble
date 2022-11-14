import 'dart:async';
import 'dart:developer';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  ScopeManager? _parent;
  // TODO: have proper root scope
  RootScope rootScope = Ensemble().rootScope();

  @override
  Map<String, dynamic>? get customViewDefinitions => pageData.customViewDefinitions;

  @override
  DataContext get dataContext => _dataContext;

  @override
  EventBus get eventBus => pageData.eventBus;

  @override
  Map<Invokable, Map<int, StreamSubscription>> get listenerMap => pageData.listenerMap;

  @override
  List<BuildContext> get openedDialogs => pageData.openedDialogs;

  /// call when the screen is being disposed
  /// TODO: consolidate listeners, location, eventBus, ...
  void dispose() {
    // cancel the screen's location listener
    pageData.locationListener?.cancel();
  }

  /// only 1 location listener per screen
  void addLocationListener(StreamSubscription<Position> streamSubscription) {
    // first cancel the previous one
    pageData.locationListener?.cancel();
    pageData.locationListener = streamSubscription;
  }

  // add repeating timer so we can manage it later.
  void addTimer(StartTimerAction timerAction, Timer timer) {
    EnsembleTimer newTimer = EnsembleTimer(timer, id: timerAction.payload?.id);

    // if timer is global, add it to the root scope. There can only be one global Timer
    if (timerAction.payload != null && timerAction.payload!.isGlobal == true) {
      rootScope.rootTimer?.cancel();
      rootScope.rootTimer = newTimer;
    }
    // use the current scope with the Invokable as the key (such that the timer
    // will automatically be cancelled when the widget is disposed). This also
    // prevents duplicate (e.g. clicking multiple times on Button that starts a timer)
    else if (timerAction.initiator != null) {
      pageData._timerMap[timerAction.initiator!]?.cancel();
      pageData._timerMap[timerAction.initiator!] = newTimer;
    }
    // save standalone timers to a simple list
    else {
      // if ID is specified, prevents duplicates by removing previous one
      if (timerAction.payload?.id != null) {
        pageData._timers.removeWhere((item) {
          if (item.id == timerAction.payload!.id) {
            item.timer.cancel();
            return true;
          }
          return false;
        });
      }
      pageData._timers.add(newTimer);
    }

  }
  @override
  void removeTimerByWidget(Invokable widget) {
    if (pageData._timerMap[widget] != null) {
      pageData._timerMap[widget]!.cancel();
      log("Cleared all Timers for widget: ${widget.id ?? widget.toString()}");
    }
  }
  void removeTimer(String timerId) {
    // first try to remove from root scope
    if (rootScope.rootTimer?.id == timerId) {
      rootScope.rootTimer?.cancel();
      rootScope.rootTimer = null;
    }
    else {
      // remove from current scope's timer map
      pageData._timerMap.removeWhere((key, value) {
        if (value.id == timerId) {
          value.timer.cancel();
          return true;
        }
        return false;
      });
      // remove from current scope's timer list
      pageData._timers.removeWhere((item) {
        if (item.id == timerId) {
          item.timer.cancel();
          return true;
        }
        return false;
      });
    }
  }




  /// create a copy of the parent's data scope
  @override
  ScopeManager createChildScope() {
    ScopeManager childScope = ScopeManager(dataContext.clone(), pageData);
    childScope._parent = this;
    return childScope;
  }

  @override
  ScopeManager get me => this;

}


abstract class IsScopeManager {
  DataContext get dataContext;
  Map<String, dynamic>? get customViewDefinitions;
  EventBus get eventBus;
  Map<Invokable, Map<int, StreamSubscription>> get listenerMap;
  void removeTimerByWidget(Invokable widget);
  List<BuildContext> get openedDialogs;
  ScopeManager createChildScope();
  ScopeManager get me;
}



/// View Helper to build our widgets from within a ScopeManager
mixin ViewBuilder on IsScopeManager {

  /// build a widget from the item YAML
  /// Note that here we build the widget using the proper scope, BUT its
  /// parent scope is not defined. This means that onAction might not
  /// have the right data context. Use @buildWidgetWithScopeFromDefinition if
  /// you want to wrap it around the right scope
  Widget buildWidgetFromDefinition(dynamic item) {
    return buildWidget(ViewUtil.buildModel(item, customViewDefinitions));
  }

  /// build a widget from the item YAML, and wrap it inside a DataScopeWidget
  /// This enables the widget to travel up and get its data context
  DataScopeWidget buildWidgetWithScopeFromDefinition(dynamic item) {
    Widget widget = buildWidget(ViewUtil.buildModel(item, customViewDefinitions));
    return DataScopeWidget(scopeManager: createChildScope(), child: widget);
  }




  /// build a widget from a given model
  Widget buildWidget(WidgetModel model) {
    // 1. Create a bare widget tree
    //  - Add Widget ID as needed to our DataContext
    //  - update the mapping of WidgetModel -> (Invokable, ScopeManager, children)
    Map<WidgetModel, ModelPayload> modelMap = {};
    ScopeNode rootNode = ScopeNode(me);
    Widget rootWidget = ViewUtil.buildBareWidget(rootNode, model, modelMap);

    // 2. from our rootScope, propagate all data to the child scopes
    ViewUtil.propagateScopes(rootNode);

    // 3. execute bindings
    //  - TODO: detect circular dependencies so we don't have infinite loop
    _updateWidgetBindings(modelMap);

    return rootWidget;





    /*
    // 1. create bare widget tree.
    //  - Add Widget ID as needed to our DataContext
    //  - update the mapping of WidgetModel -> Widget
    Map<WidgetModel, Invokable> widgetMap = {};
    Widget widget = _buildBareWidget(model, widgetMap);

    // 2. execute bindings
    //  - TODO: detect circular dependencies so we don't have infinite loop
    _updateWidgetBindings(widgetMap);

    return widget;*/
  }

  void _updateWidgetBindings(Map<WidgetModel, ModelPayload> modelMap) {

    modelMap.forEach((model, payload) {
      ScopeManager scopeManager = payload.scopeManager;
      DataContext dataContext = scopeManager.dataContext;

      // resolve input parameters
      if (model is CustomWidgetModel) {
        if (model.parameters != null && model.inputs != null) {
          for (var param in model.parameters!) {
            if (model.inputs![param] != null) {
              // set the Custom Widget's inputs from parent scope
              setPropertyAndRegisterBinding(
                  scopeManager._parent!,    // widget inputs are set in the parent's scope
                  payload.widget as Invokable,
                  param,
                  model.inputs![param]);
            }
          }
        }
        return;
      }

      //WidgetModel model = inputModel is CustomWidgetModel ? inputModel.getModel() : inputModel;

      if (payload.widget is Invokable) {
        Invokable widget = payload.widget as Invokable;
        // set props and styles on the widget. At this stage the widget
        // has not been attached, so no worries about ValueNotifier
        for (String key in model.props.keys) {
          if (InvokableController.getSettableProperties(widget).contains(key)) {
            // actions like onTap should evaluate its expressions upon the action only
            if (key.startsWith('on')) {
              InvokableController.setProperty(widget, key, model.props[key]);
            } else {
              setPropertyAndRegisterBinding(
                  scopeManager, widget, key, model.props[key]);
            }
          }
        }
        for (String key in model.styles.keys) {
          if (InvokableController.getSettableProperties(widget).contains(key)) {
            setPropertyAndRegisterBinding(
                scopeManager, widget, key, model.styles[key]);
          }
        }
      }

      if (payload.widget is UpdatableContainer) {
        // evaluate the itemTemplate data as initial value
        if (model.itemTemplate != null) {
          dynamic initialValue = dataContext.eval(model.itemTemplate!.data);
          if (initialValue is List) {
            model.itemTemplate!.initialValue = initialValue;
          }
        }
        (payload.widget as UpdatableContainer).initChildren(
            children: payload.children, itemTemplate: model.itemTemplate);
      }

    });
  }

  /// iterate through and set/evaluate the widget's properties/styles/...
  /*void _updateWidgetBindings(Map<WidgetModel, Invokable> widgetMap) {

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
  }*/

  /// call widget.setProperty to update its value.
  /// If the value is an expression of valid binding, we
  /// will register to listen for changes
  void setPropertyAndRegisterBinding(ScopeManager scopeManager, Invokable widget, String key, dynamic value) {
    if (value is String) {
      DataExpression? expression = Utils.parseDataExpression(value);
      if (expression != null) {
        // listen for binding changes
        (this as PageBindingManager).registerBindingListener(
            scopeManager,
            BindingDestination(widget, key),
            expression
        );
        // evaluate the binding as the initial value
        value = scopeManager.dataContext.eval(value);
      }
    }
    InvokableController.setProperty(widget, key, value);

  }
}



/// managing binding at the Page level.
/// It does this by tapping into the page-level's PageData
mixin PageBindingManager on IsScopeManager {


  /// Evaluate a binding expression and listen for changes.
  /// Calling this multiple times is safe as we remove the matching listeners before adding.
  /// Upon changes, execute setProperty() on the destination's Invokable
  /// The expression can be a mix of variable and text e.g Hello $(first) $(last)
  void registerBindingListener(ScopeManager scopeManager, BindingDestination bindingDestination, DataExpression dataExpression) {

    // we re-evaluate the entire raw binding upon any changes to any variables
    for (var expression in dataExpression.expressions) {
      listen(scopeManager, expression, destination: bindingDestination, onDataChange: (ModelChangeEvent event) {

        DataContext dataContext = scopeManager.dataContext;
        /*
        if (dataContext.getContextById(event.modelId) is InvokablePrimitive) {
          updateInvokablePrimitive(
              dataContext,
              event.modelId,
              dataContext.getContextById(bindingDestination.setterProperty),
              event.payload);
        }
        */
        // payload only have changes to a variable, but we have to evaluate the entire expression
        // e.g Hello $(firstName.value) $(lastName.value)
        dynamic updatedValue = dataContext.eval(dataExpression.stringifyRawAndAst());
        InvokableController.setProperty(bindingDestination.widget, bindingDestination.setterProperty, updatedValue);
      });
    }
  }

  // void updateInvokablePrimitive(DataContext dataContext, String key, InvokablePrimitive primitive, dynamic newValue) {
  //   if (newValue == null) {
  //     dataContext.addInvokableContext(key, InvokableNull());
  //   } else {
  //     if (primitive is InvokableString) {
  //       dataContext.addInvokableContext(key, InvokableString(newValue.toString()));
  //     } else if (primitive is InvokableBoolean && newValue is bool) {
  //       dataContext.addInvokableContext(key, InvokableBoolean(newValue));
  //     } else if (primitive is InvokableNumber && newValue is num) {
  //       dataContext.addInvokableContext(key, InvokableNumber(newValue));
  //     }
  //   }
  // }


  /// listen for changes on the bindingExpression and invoke onDataChange() callback.
  /// Multiple calls to this is safe as we remove the existing listeners before adding.
  /// [bindingExpression] a valid binding expression in the form of getter e.g $(myText.text)
  /// [me] the widget that initiated this listener. We need this to properly remove
  /// [bindingScope] if specified, we'll only listen to binding changes within this Scope (e.g. custom widget inputs)
  /// all listeners when the widget is disposed.
  /// @return true if we are able to bind and listen to the expression.
  bool listen(
      ScopeManager scopeManager,
      String bindingExpression, {
        required BindingDestination destination,
        required Function onDataChange
      }) {
    DataContext dataContext = scopeManager.dataContext;

    BindingSource? bindingSource = BindingSource.from(bindingExpression, dataContext);
    if (bindingSource != null) {
      // create a unique key to reference our listener. We used this to save
      // the listeners for clean up
      // Note that simple binding (i.e. custom widget's input variable) needs
      // scopeManager to uniquely identify them (since multiple custom widgets
      // can be created.
      int hash = getHash(
          destinationSetter: destination.setterProperty,
          source: bindingSource,
          scopeManager: bindingSource is SimpleBindingSource ? scopeManager : null
      );

      // clean up existing listener with the same signature
      if (listenerMap[destination.widget]?[hash] != null) {
        //log("Binding(remove duplicate): ${me.id}-${bindingSource.modelId}-${bindingSource.property}");
        listenerMap[destination.widget]![hash]!.cancel();
      }
      StreamSubscription subscription = eventBus.on<ModelChangeEvent>()
          .listen((event) {
        //log("EventBus ${eventBus.hashCode} listening: $event");
        if (event.source.runtimeType == bindingSource.runtimeType &&
            event.source.modelId == bindingSource.modelId &&
            (event.source.property == null || event.source.property == bindingSource.property) &&
            (event.bindingScope == null || event.bindingScope == scopeManager)) {
                onDataChange(event);
        }
      });

      // save to the listener map so we can remove later
      if (listenerMap[destination.widget] == null) {
        listenerMap[destination.widget] = {};
      }
      //log("Binding: Adding ${me.id}-${bindingSource.modelId}-${bindingSource.property}");
      listenerMap[destination.widget]![hash] = subscription;
      //log("All Bindings:${listenerMap.toString()} ");

      return true;

    }
    return false;

  }

  void dispatch(ModelChangeEvent event) {
    //log("EventBus ${eventBus.hashCode} firing $event");
    eventBus.fire(event);
  }

  /// upon widget being disposed, we need to remove all listeners associated with it
  void disposeWidget(Invokable widget) {
    // remove all listeners associated with this Invokable
    if (listenerMap[widget] != null) {
      for (StreamSubscription listener in listenerMap[widget]!.values) {
        listener.cancel();
      }
      //log("Binding : Disposing ${widget}(${widget.id ?? ''}). Removing ${listenerMap[widget]!.length} listeners");
      listenerMap.remove(widget);
    }
    // remove all Timers associated with this Invokable
    removeTimerByWidget(widget);

  }

  /// unique but repeatable hash (within the same session) of the provided keys
  int getHash({String? destinationSetter, required BindingSource source, ScopeManager? scopeManager}) {
    return Object.hash(destinationSetter, source.modelId, source.property, source.runtimeType, scopeManager);
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





/// data for the current Page.
class PageData {
  PageData({
    this.customViewDefinitions,
    this.apiMap
  }) {
    //log("EventBus ${eventBus.hashCode} created");
  }

  // we'll have 1 EventBus and listenerMap for each Page
  final EventBus eventBus = EventBus();
  final Map<Invokable, Map<int, StreamSubscription>> listenerMap = {};

  // When repeating timers are created at the page level, we need to manage
  // duplicates as well as the ability to pause (navigate to new page) or
  // cancel them (when the page is disposed).
  // We tie the listeners to Invokable to prevent duplicates (e.g. same timer started multiple times on button click),
  // but also a way to cancel the timer when the widget is destroyed.
  // When a timer is not tie to a widget, we add them to a simple list.
  final Map<Invokable, EnsembleTimer> _timerMap = {};
  final List<EnsembleTimer> _timers = [];

  /// 1 recurring location listener per page
  StreamSubscription<Position>? locationListener;

  // list of all opened Dialogs' contexts
  final List<BuildContext> openedDialogs = [];


  // store the raw definition of the SubView (to be accessed by itemTemplates)
  final Map<String, dynamic>? customViewDefinitions;

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

/// representing a one-line expression that evaluates to a value
/// e.g 'My name is ${person.first_name} ${person.last_name}'
/// This may also contain an equivalent AST definition, which we'll use to
/// execute by default, otherwise fallback to execute the expression directly.
class DataExpression {
  DataExpression({
    required this.rawExpression,
    required this.expressions,
    this.astExpression});

  // the original raw expression e.g my name is ${person.first_name} ${person.last_name}
  String rawExpression;
  // each expression in a list e.g [person.first_name, person.last_name]
  List<String> expressions;
  // the AST which we'll execute by default, and fallback to executing rawExpression
  String? astExpression;

  // combine both the raw and AST as if they are coming from the server
  String stringifyRawAndAst() {
    if (astExpression != null) {
      return '//@code $rawExpression\n$astExpression';
    }
    return rawExpression;
  }
}

/// a wrapper around a repeating timer with optional ID.
/// We use this to manage Timers
class EnsembleTimer {
  EnsembleTimer(this.timer, {this.id});
  Timer timer;
  String? id;

  void cancel() {
    timer.cancel();
  }
}