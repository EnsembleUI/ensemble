import 'dart:developer';

import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/custom_widget/custom_widget_model.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class CustomWidget extends EnsembleWidget<CustomWidgetController> {
  CustomWidget._(super.controller,
      {super.key, required this.model, required this.scopeManager}) {
    log("Custom Widget $hashCode created");
  }

  final CustomWidgetModel model;
  final ScopeManager scopeManager;

  factory CustomWidget(dynamic controller,
          {required CustomWidgetModel model,
          required ScopeManager scopeManager}) =>
      CustomWidget._(
          controller is CustomWidgetController
              ? controller
              : CustomWidgetController(
                  model: model, scopeManager: scopeManager),
          model: model,
          scopeManager: scopeManager);

  @override
  State<StatefulWidget> createState() => _CustomWidgetState();
}

class CustomWidgetController extends EnsembleWidgetController {
  CustomWidgetController({required this.model, required this.scopeManager});

  final CustomWidgetModel model;
  final ScopeManager scopeManager;

  /// override to control setting input parameters
  /// as well as dispatching changes
  @override
  void setProperty(dynamic prop, dynamic val) {
    var parameters = model.parameters;
    var events = model.events;

    // handle params/events ourselves
    if (prop != null && (parameters != null && parameters.contains(prop)) ||
            (events != null && events.containsKey(prop))
        //this does mean that an input must not have the same name as an event
        ) {
      // override the key
      if (val is Invokable) {
        scopeManager.dataContext.addInvokableContext(prop, val);
      } else {
        scopeManager.dataContext.addDataContextById(prop, val);
      }

      // dispatch the changes to all inside our Custom Widget scope
      //log("Dispatching ${prop}=${val}. Scope ${scopeManager.hashCode}");
      scopeManager.dispatch(ModelChangeEvent(SimpleBindingSource(prop), val,
          bindingScope: scopeManager));
    }
    // use super class to handle the rest of the properties
    else {
      super.setProperty(prop, val);
    }
  }
}

class _CustomWidgetState extends EnsembleWidgetState<CustomWidget> {
  @override
  void initState() {
    super.initState();
    CustomWidgetLifecycle lifecycleActions = widget.model.getLifecycleActions();
    if (lifecycleActions.onLoad != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScreenController().executeAction(context, lifecycleActions.onLoad!);
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) =>
      widget.scopeManager.buildWidget(widget.model.getModel());
}
