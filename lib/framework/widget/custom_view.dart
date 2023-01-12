import 'dart:developer';

import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/cupertino.dart';

/// represent a Custom View declared in a yaml screen
class CustomView extends StatelessWidget with Invokable {
  CustomView(
      {super.key,
      required this.childWidget,
      this.parameters,
      required this.scopeManager,
      required this.viewBehavior}) {
    if (parameters != null) {
      // add placeholder so listeners can be attached to it
      for (var param in parameters!) {
        scopeManager.dataContext.addInvokableContext(param, InvokableNull());
      }
    }
    log("Custom View created $hashCode");
  }

  final List<String>? parameters;
  final Widget childWidget;
  final ScopeManager scopeManager;
  final ViewBehavior viewBehavior;
  bool onLoadExecuted = false;

  @override
  Widget build(BuildContext context) {
    // execute onLoad once if applicable
    if (viewBehavior.onLoad != null && !onLoadExecuted) {
      ScreenController().executeAction(context, viewBehavior.onLoad!);
      onLoadExecuted = true;
    }
    return childWidget;
  }

  /// override to control setting input parameters
  /// as well as dispatching changes
  @override
  void setProperty(dynamic prop, dynamic val) {
    if (prop != null && parameters != null && parameters!.contains(prop)) {
      Object value;
      if (val == null) {
        value = InvokableNull();
      } else {
        value = val;
      }
      // override the key
      if (value is Invokable) {
        scopeManager.dataContext.addInvokableContext(prop, value);
      } else {
        scopeManager.dataContext.addDataContextById(prop, value);
      }

      // dispatch the changes to all inside our Custom Widget scope
      //log("Dispatching ${prop}=${val}. Scope ${scopeManager.hashCode}");
      scopeManager.dispatch(ModelChangeEvent(SimpleBindingSource(prop), val,
          bindingScope: scopeManager));
    }
  }

  @override
  Map<String, Function> getters() {
    throw UnimplementedError();
  }

  @override
  Map<String, Function> methods() {
    throw UnimplementedError();
  }

  @override
  Map<String, Function> setters() {
    throw UnimplementedError();
  }
}
