import 'dart:developer';

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/cupertino.dart';

/// represent a Custom View declared in a yaml screen
class CustomView extends StatelessWidget with Invokable {
  CustomView({
      super.key,
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

  }

  final List<String>? parameters;
  final Widget childWidget;
  final ScopeManager scopeManager;
  final ViewBehavior viewBehavior;



  @override
  Widget build(BuildContext context) {
    // execute onLoad if applicable
    if (viewBehavior.onLoad != null) {
      ScreenController().executeAction(context, viewBehavior.onLoad!);
    }
    return childWidget;
  }

  /// override to control setting input parameters
  /// as well as dispatching changes
  @override
  void setProperty(dynamic prop, dynamic val) {
    if (prop != null && parameters != null && parameters!.contains(prop)) {
      Invokable value;
      if (val is bool) {
        value = InvokableBoolean(val);
      } else if (val is num) {
        value = InvokableNumber(val);
      } else if (val != null) {
        value = InvokableString(val.toString());
      } else {
        value = InvokableNull();
      }
      // override the key
      scopeManager.dataContext.addInvokableContext(prop, value);

      // dispatch the changes to all inside our Custom Widget scope
      //log("Dispatching ${prop}=${val}. Scope ${scopeManager.hashCode}");
      scopeManager.dispatch(ModelChangeEvent(prop, val, bindingScope: scopeManager));
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