import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:ensemble/controller/controller_mixins.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:web_socket_client/web_socket_client.dart';
import 'package:yaml/yaml.dart';

/// ScopeManager handles all data/view relative to a Scope. It also has a
/// reference to the page-level PageData.
/// This class is a composite:
///  - ViewBuilder: helper class with building widgets
///  - PageBindingManager: managing event bindings at the page level
class ScopeManager extends IsScopeManager with ViewBuilder, PageBindingManager {
  ScopeManager(this._dataContext, this.pageData, {this.ephemeral = false});

  bool ephemeral;
  final DataContext _dataContext;
  final PageData pageData;
  ScopeManager? _parent;

  // TODO: have proper root scope
  RootScope rootScope = Ensemble().rootScope();

  @override
  Map<String, dynamic>? get customViewDefinitions =>
      pageData.customViewDefinitions;

  @override
  DataContext get dataContext => _dataContext;

  @override
  EventBus get eventBus => pageData.eventBus;

  @override
  Map<Invokable, Map<int, StreamSubscription>> get listenerMap =>
      pageData.listenerMap;

  @override
  List<BuildContext> get openedDialogs => pageData.openedDialogs;

  /// call when the screen is being disposed
  /// TODO: consolidate listeners, location, eventBus, ...
  void dispose() {
    // clear out all event listeners
    eventBus.destroy();

    // cancel all timers bound to Invokable
    pageData._timerMap.forEach((_, timer) {
      timer.cancel();
    });
    // cancel all standalone timers
    for (var timer in pageData._timers) {
      timer.cancel();
    }

    // cancel the screen's location listener
    pageData.locationListener?.cancel();

    SocketService().dispose();
  }

  /// only 1 location listener per screen
  void addLocationListener(
      StreamSubscription<LocationData> streamSubscription) {
    // first cancel the previous one
    pageData.locationListener?.cancel();
    pageData.locationListener = streamSubscription;
  }

  // add repeating timer so we can manage it later.
  void addTimer(StartTimerAction timerAction, Timer timer) {
    EnsembleTimer newTimer = EnsembleTimer(timer, id: timerAction.id);

    // if timer is global, add it to the root scope. There can only be one global Timer
    if (timerAction.isGlobal(dataContext) == true) {
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
      if (timerAction.id != null) {
        pageData._timers.removeWhere((item) {
          if (item.id == timerAction.id) {
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
    } else {
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
  ScopeManager createChildScope({bool ephemeral = false}) {
    ScopeManager childScope =
        ScopeManager(dataContext.clone(), pageData, ephemeral: ephemeral);
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

typedef AfterWidgetCreationCallback = Function();

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
    Widget widget =
        buildWidget(ViewUtil.buildModel(item, customViewDefinitions));
    return DataScopeWidget(scopeManager: createChildScope(), child: widget);
  }

  Widget buildRootWidget(
      WidgetModel rootModel, AfterWidgetCreationCallback? callback) {
    return _buildWidget(rootModel, callback: callback);
  }

  /// build a widget from a given model
  Widget buildWidget(WidgetModel model) {
    return _buildWidget(model);
  }

  Widget _buildWidget(WidgetModel model,
      {AfterWidgetCreationCallback? callback}) {
    // 1. Create a bare widget tree
    //  - Add Widget ID as needed to our DataContext
    //  - update the mapping of WidgetModel -> (Invokable, ScopeManager, children)
    Map<WidgetModel, ModelPayload> modelMap = {};
    ScopeNode rootNode = ScopeNode(me);
    Widget rootWidget = ViewUtil.buildBareWidget(rootNode, model, modelMap);

    // 2. In special cases after the widgets are created (but before
    // the scope data is propagate and before binding), we want to
    // update the scope data.
    // An example is RootScope requires the widgets to be instantiate, then
    // run the Global block (since this block may want to reference the widgets).
    // Only then we proceed to propagate the scopes and trigger bindings.
    if (callback != null) {
      callback();
    }

    // 3. from our rootScope, propagate all data to the child scopes
    ViewUtil.propagateScopes(rootNode);

    // 4. execute bindings
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
              evalPropertyAndRegisterBinding(
                  // widget inputs are set in the parent's scope
                  scopeManager._parent!,
                  payload.widget as Invokable,
                  param,
                  model.inputs![param]);
            }
          }
        }
        return;
      }

      //WidgetModel model = inputModel is CustomWidgetModel ? inputModel.getModel() : inputModel;

      Invokable? invokable;
      if (payload.widget is EnsembleWidget) {
        invokable = (payload.widget as EnsembleWidget).controller;
      } else if (payload.widget is Invokable) {
        invokable = payload.widget as Invokable;
      }
      if (invokable != null) {
        // set props and styles on the widget. At this stage the widget
        // has not been attached, so no worries about ValueNotifier
        for (String key in model.props.keys) {
          if (InvokableController.getSettableProperties(invokable)
              .contains(key)) {
            if (_isPassthroughProperty(key, invokable)) {
              InvokableController.setProperty(invokable, key, model.props[key]);
            } else {
              evalPropertyAndRegisterBinding(
                  scopeManager, invokable, key, model.props[key]);
            }
          }
        }
        for (String key in model.styles.keys) {
          if (InvokableController.getSettableProperties(invokable)
              .contains(key)) {
            if (_isPassthroughProperty(key, invokable)) {
              InvokableController.setProperty(
                  invokable, key, model.styles[key]);
            } else {
              evalPropertyAndRegisterBinding(
                  scopeManager, invokable, key, model.styles[key]);
            }
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

  /// some properties should automatically be excluded from being evaluated
  /// at this point, and some can be excluded manually by the widget builders:
  /// 1. all Actions (starting with on*) should eval their variables
  ///    at the time the action is executed (to prevent stale-ness)
  /// 2. Widgets can mark certain properties as pass-through so the
  ///    variable evaluation can be done inside the widget
  /// 3. Special properties like children and item-template are excluded
  ///    automatically and don't need to be specified here
  bool _isPassthroughProperty(String property, dynamic widget) =>
      property.startsWith('on') ||
      (widget is HasController &&
          widget.passthroughSetters().contains(property)) ||
      (widget is HasPassThrough &&
          widget.passthroughSetters().contains(property));

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

  /// evaluate the value and call widget's setProperty with this value.
  /// If the value is a valid binding, we'll register to listen for changes.
  void evalPropertyAndRegisterBinding(
      ScopeManager scopeManager, Invokable widget, String key, dynamic value) {
    DataExpression? expression = Utils.parseDataExpression(value);
    if (expression != null) {
      // listen for binding changes
      (this as PageBindingManager).registerBindingListener(
          scopeManager, BindingDestination(widget, key), expression);
      // evaluate the binding as the initial value
      value = scopeManager.dataContext.eval(value);
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
  void registerBindingListener(ScopeManager scopeManager,
      BindingDestination bindingDestination, DataExpression dataExpression) {
    // we re-evaluate the entire raw binding upon any changes to any variables
    for (var expression in dataExpression.expressions) {
      listen(scopeManager, expression, destination: bindingDestination,
          onDataChange: (ModelChangeEvent event) {
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
        dynamic updatedValue = dataContext.eval(dataExpression.rawExpression);
        InvokableController.setProperty(bindingDestination.widget,
            bindingDestination.setterProperty, updatedValue);
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

  /// remove all the binding listeners that this widget is listening to.
  /// Call this when a widget is disposed
  void removeBindingListeners(Invokable destinationWidget) {
    // int? count = listenerMap[destinationWidget]?.values.length;
    // if (count != null) {
    //   log("Removing ${count} binding listeners for (${destinationWidget.runtimeType} - ${destinationWidget.hashCode})");
    // }
    listenerMap[destinationWidget]?.values.forEach((e) => e.cancel());
  }

  /// listen for changes on the bindingExpression and invoke onDataChange() callback.
  /// Multiple calls to this is safe as we remove the existing listeners before adding.
  /// [bindingExpression] a valid binding expression in the form of getter e.g $(myText.text)
  /// [me] the widget that initiated this listener. We need this to properly remove
  /// [bindingScope] if specified, we'll only listen to binding changes within this Scope (e.g. custom widget inputs)
  /// all listeners when the widget is disposed.
  /// @return true if we are able to bind and listen to the expression.
  void listen(ScopeManager scopeManager, String bindingExpression,
      {required BindingDestination destination,
      required Function onDataChange}) {
    DataContext dataContext = scopeManager.dataContext;

    List<BindingSource> bindingSources =
        BindingSource.getBindingSources(bindingExpression, dataContext);
    // fallback to find the binding source the legacy way
    if (bindingSources.isEmpty) {
      BindingSource? bindingSource =
          BindingSource.from(bindingExpression, dataContext);
      if (bindingSource != null) {
        bindingSources.add(bindingSource);
      }
    }

    // iterate and listen to each binding source
    for (BindingSource bindingSource in bindingSources) {
      _listenToBindingSource(scopeManager, bindingSource,
          destination: destination, onDataChange: onDataChange);
    }
  }

  void _listenToBindingSource(
      ScopeManager scopeManager, BindingSource bindingSource,
      {required BindingDestination destination,
      required Function onDataChange}) {
    // create a unique key to reference our listener. We used this to save
    // the listeners for clean up
    // Note that simple binding (i.e. custom widget's input variable) needs
    // scopeManager to uniquely identify them (since multiple custom widgets
    // can be created.
    int hash = getHash(
        destinationSetter: destination.setterProperty,
        source: bindingSource,
        scopeManager: (bindingSource is SimpleBindingSource ||
                bindingSource is DeferredBindingSource)
            ? scopeManager
            : null);

    // clean up existing listener with the same signature
    if (listenerMap[destination.widget]?[hash] != null) {
      //log("Binding(remove duplicate): ${me.id}-${bindingSource.modelId}-${bindingSource.property}");
      listenerMap[destination.widget]![hash]!.cancel();
    }
    StreamSubscription subscription =
        eventBus.on<ModelChangeEvent>().listen((event) {
      //log("EventBus ${eventBus.hashCode} listening: $event");
      if ((bindingSource is DeferredBindingSource ||
              event.source.runtimeType == bindingSource.runtimeType) &&
          event.source.modelId == bindingSource.modelId &&
          (event.source.property == null ||
              event.source.property == bindingSource.property) &&
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
  }

  void dispatch(ModelChangeEvent event) {
    //log("EventBus ${eventBus.hashCode} firing $event");
    eventBus.fire(event);
  }

  /// unique but repeatable hash (within the same session) of the provided keys
  int getHash(
      {String? destinationSetter,
      required BindingSource source,
      ScopeManager? scopeManager}) {
    return Object.hash(destinationSetter, source.modelId, source.property,
        source.runtimeType, scopeManager);
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
  PageData({this.customViewDefinitions, this.apiMap, this.socketData}) {
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
  StreamSubscription<LocationData>? locationListener;

  // list of all opened Dialogs' contexts
  final List<BuildContext> openedDialogs = [];

  // store the raw definition of the SubView (to be accessed by itemTemplates)
  final Map<String, dynamic>? customViewDefinitions;

  // API model mapping
  Map<String, YamlMap>? apiMap;
  Map<String, EnsembleSocket>? socketData;

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
  DataExpression({required this.rawExpression, required this.expressions});

  // the original raw expression e.g my name is ${person.first_name} ${person.last_name}
  // or it can be a List [${first} ${last}, 4, ${anotherVar}]
  // or it can be 1-level Map
  dynamic rawExpression;

  // each expression in a list e.g [person.first_name, person.last_name]
  List<String> expressions;
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

class EnsembleSocket {
  final List<String> inputs;
  final String uri;
  final SocketOptions options;

  // callbacks
  final EnsembleAction? onSuccess;
  final EnsembleAction? onError;
  final EnsembleAction? onDisconnect;
  final EnsembleAction? onReconnecting;
  final EnsembleAction? onReceive;

  factory EnsembleSocket.fromYaml({YamlMap? payload}) {
    if (payload == null || payload['uri'] == null) {
      throw LanguageError("Socket requires uri to connect");
    }
    return EnsembleSocket(
      inputs: Utils.getList(payload['inputs'])?.cast<String>() ?? [],
      uri: Utils.getString(payload['uri'], fallback: ''),
      options: SocketOptions.fromYaml(payload: payload['options']),
      onReceive: EnsembleAction.fromYaml(payload['onReceive']),
      onSuccess: EnsembleAction.fromYaml(payload['onSuccess']),
      onError: EnsembleAction.fromYaml(payload['onError']),
      onDisconnect: EnsembleAction.fromYaml(payload['onDisconnect']),
      onReconnecting: EnsembleAction.fromYaml(payload['onReconnectAttempt']),
    );
  }

  EnsembleSocket({
    this.inputs = const [],
    required this.uri,
    required this.options,
    this.onReceive,
    this.onSuccess,
    this.onError,
    this.onDisconnect,
    this.onReconnecting,
  });
}

class SocketOptions {
  final bool autoReconnect;
  final bool disconnctOnPageClose;
  final int reconnectInitialTimer;
  final int reconnectMaxStep;

  SocketOptions({
    this.autoReconnect = true,
    this.disconnctOnPageClose = true,
    this.reconnectInitialTimer = 1,
    this.reconnectMaxStep = 3,
  });

  factory SocketOptions.fromYaml({YamlMap? payload}) {
    return SocketOptions(
      autoReconnect: Utils.getBool(payload?['autoReconnect'], fallback: true),
      disconnctOnPageClose:
          Utils.getBool(payload?['disconnctOnPageClose'], fallback: true),
      reconnectInitialTimer:
          Utils.getInt(payload?['reconnectInitialTimer'], fallback: 1),
      reconnectMaxStep: Utils.getInt(payload?['reconnectMaxStep'], fallback: 1),
    );
  }
}

class SocketService {
  static Map<String, EnsembleSocket> socketData = {};
  static Map<String, WebSocket> activeConnections = {};
  static Map<String, StreamSubscription> subscriptions = {};
  static Map<String, StreamSubscription> connectionStateSubscriptions = {};

  SocketService._internal();

  static final SocketService _instance = SocketService._internal();

  factory SocketService() {
    return _instance;
  }

  (WebSocket, EnsembleSocket) connect(
      String socketName, Function(String uri) resolveURI) {
    final data = socketData[socketName];
    if (data == null) {
      throw LanguageError('Please define socket first');
    }
    Backoff? backoff;
    if (data.options.autoReconnect) {
      backoff = BinaryExponentialBackoff(
        initial: Duration(seconds: data.options.reconnectInitialTimer),
        maximumStep: data.options.reconnectMaxStep,
      );
    }
    final uri = resolveURI(data.uri);

    final socket = WebSocket(
      uri,
      backoff: backoff,
    );

    activeConnections[socketName] = socket;
    return (socket, data);
  }

  void message(String socketName, dynamic message) {
    final socket = activeConnections[socketName];
    socket?.send(jsonEncode(message));
  }

  Future<void> disconnect(String socketName) async {
    final socket = activeConnections[socketName];
    final subscription = subscriptions[socketName];
    socket?.close();
    await subscription?.cancel();
    if (socket != null) activeConnections.remove(socketName);
    if (subscription != null) subscriptions.remove(socketName);
  }

  void setSubscription(String socketName, StreamSubscription subscription) {
    subscriptions[socketName] = subscription;
  }

  void setConnectionSubscription(
      String socketName, StreamSubscription subscription) {
    connectionStateSubscriptions[socketName] = subscription;
  }

  Future<void> dispose() async {
    for (var element in socketData.entries) {
      if (element.value.options.disconnctOnPageClose == true) {
        await disconnect(element.key);
      }
    }
  }
}
