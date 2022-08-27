import 'package:ensemble/framework/action.dart' as action;
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

/// base mixin for Ensemble Container (e.g Column)
mixin UpdatableContainer<T extends Widget> {
  void initChildren({List<T>? children, ItemTemplate? itemTemplate});
}


/// base Controller class for your Ensemble widget
abstract class WidgetController extends Controller {

  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets
  bool expanded = false;
  bool visible = true;

  // optional label/labelHint for use in Forms
  String? label;
  String? labelHint;

  @override
  Map<String, Function> getBaseGetters() {
    return {
      'expanded': () => expanded,
      'visible': () => visible,
    };
  }

  @override
  Map<String, Function> getBaseSetters() {
    return {
      'expanded': (value) => expanded = Utils.getBool(value, fallback: false),
      'visible': (value) => visible = Utils.getBool(value, fallback: true),
      'label': (value) => label = Utils.optionalString(value),
      'labelHint': (value) => labelHint = Utils.optionalString(value),
    };
  }
}

/// base class for widgets that want to participate in Ensemble layout
abstract class WidgetState<W extends HasController> extends BaseWidgetState<W> {
  ScopeManager? _scopeManager;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeManager = DataScopeWidget.getScope(context);
  }

  // notify our ScopeManager that the widget is being disposed
  @override
  void dispose() {
    if (widget is Invokable) {
      _scopeManager?.disposeWidget(widget as Invokable);
    }
    super.dispose();
  }

  @override
  void changeState() {
    super.changeState();
    // dispatch changes, so anything binding to this will be notified
    if (widget.controller.lastSetterProperty != null) {
      if (_scopeManager != null && widget is Invokable && (widget as Invokable).id != null) {
        _scopeManager!.dispatch(ModelChangeEvent(
            (widget as Invokable).id!,
            widget.controller.lastSetterProperty!.value,
            property: widget.controller.lastSetterProperty!.key));
      }
      widget.controller.lastSetterProperty = null;
    }
  }
}


