import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/widget/custom_widget/custom_widget.dart';
import 'package:ensemble/widget/custom_widget/custom_widget_model.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// build a widget given a scopeManager
class EnsembleWidgetBuilder {
  EnsembleWidgetBuilder(this.scopeManager);

  final ScopeManager scopeManager;

  Widget? build(WidgetModel model, {AfterWidgetCreationCallback? callback}) {
    // 1. first build a plain widget and optionally register its ID in the data context
    final widgetAndController = _buildWidget(model);
    if (widgetAndController != null) {
      // 2. invoke the callback
      if (callback != null) {
        callback();
      }
      // 3. update the controller data if created brand new
      if (!widgetAndController.controllerFromCache || !model.useCache) {
        _populateControllerData(widgetAndController.controller, model);
      }
      return widgetAndController.widget;
    }
    return null;
  }

  _WidgetAndController? _buildWidget(WidgetModel model) {
    EnsembleWidget? w;
    ScopeManager? customWidgetScope;
    if (model is CustomWidgetModel) {
      // custom widget needs its own scope
      customWidgetScope =
          scopeManager.createChildScope(childImportedCode: model.importedCode);
      w = CustomWidget(model: model, scopeManager: customWidgetScope);
    } else {
      w = WidgetRegistry().widgetMap[model.type]?.call();
    }

    if (w != null) {
      // find the existing controller from pageData or create a new one.
      // If create new, register it to the pageData
      final widgetKey = '${model.type}:${model.path}';
      var controller = scopeManager.getWidgetController(widgetKey);
      bool controllerFromCache = controller != null;
      if (!controllerFromCache) {
        controller = w.createController() as EnsembleWidgetController;
        // save the model xPath to the controller so it can be used when
        // creating child widgets internally on the fly.
        controller.modelPath = model.path;
        scopeManager.registerWidgetController(widgetKey, controller);
      }
      // init the controller on this new widget
      w.initController(controller);

      // set the children or itemTemplate if applicable
      if (w is UpdatableContainer) {
        (w as UpdatableContainer).initChildren(
            children: model.children, itemTemplate: model.itemTemplate);
      } else if (w is HasItemTemplate && model.itemTemplate != null) {
        (w as HasItemTemplate).setItemTemplate(model.itemTemplate!);
      }

      // for Custom Widget, we have to wrap it inside a DataScopeWidget
      return _WidgetAndController(
          controller: controller,
          controllerFromCache: controllerFromCache,
          widget: w is CustomWidget
              ? DataScopeWidget(
                  debugLabel: "CustomWidget",
                  scopeManager: customWidgetScope!,
                  child: w)
              : w);
    }
    return null;
  }

  void _populateControllerData(
      EnsembleController controller, WidgetModel model) {
    controller.definition = model.definition;
    // If our widget has an ID, add it to our data context
    String? id = model.props['id']?.toString();
    if (id != null) {
      controller.id = id;
      scopeManager.dataContext.addInvokableContext(id, controller);
    }

    List<String> excludedProperties = [];

    /// process Custom Widget-specific properties
    if (model is CustomWidgetModel) {
      excludedProperties
          .addAll(_populateCustomWidgetControllerData(controller, model));
    }

    // first populate the root properties
    scopeManager.setProperties(scopeManager, controller, model.props,
        excludedProperties: excludedProperties);

    // then styles
    HasStyles? hasStyles =
        controller is HasStyles ? controller as HasStyles : null;
    if (hasStyles != null) {
      EnsembleThemeManager()
          .configureStyles(scopeManager.dataContext, model, hasStyles);
      if (hasStyles.runtimeStyles != null) {
        scopeManager.setProperties(
            scopeManager, controller, hasStyles.runtimeStyles!);
        //not so lovely but now we set the styleOverrides to null because setting the properties could have set them
        hasStyles.styleOverrides = null;
      }
      hasStyles.stylesNeedResolving = false;
    } else {
      if (model.inlineStyles != null) {
        scopeManager.setProperties(
            scopeManager, controller, model.inlineStyles!);
      }
    }

    //TODO: set children/itemTemplate
  }

  /// Evaluate the Custom Widget's inputs/events and the listen for changes.
  /// Return the properties we handled here so they don't get processed again.
  List<String> _populateCustomWidgetControllerData(
      EnsembleController controller, CustomWidgetModel model) {
    List<String> excludedProperties = [];

    // Note that the scopeManager here is the Scope where the custom widget is used (parent scope),
    // which is exactly what we need because we resolve the params there

    // evaluate the Custom Widget's input params and listen for changes
    if (model.parameters != null && model.inputs != null) {
      for (var param in model.parameters!) {
        if (model.inputs![param] != null) {
          // set the Custom Widget's inputs from parent scope
          scopeManager.evalPropertyAndRegisterBinding(
              scopeManager, controller, param, model.inputs![param]);
        }
      }
      excludedProperties.add("parameters");
    }
    // events and such
    if (model.events != null && model.actions != null) {
      for (var event in model.events!.keys) {
        if (model.actions![event] != null) {
          // set the Custom Widget's inputs from parent scope
          scopeManager.registerEventHandler(
              // widget inputs are set in the parent's scope
              scopeManager,
              controller,
              event,
              model.actions![event]!);
        }
      }
      excludedProperties.add("events");
    }
    return excludedProperties;
  }
}

class _WidgetAndController {
  _WidgetAndController(
      {required this.widget,
      required this.controller,
      required this.controllerFromCache});

  final Widget widget;
  final EnsembleController controller;
  bool controllerFromCache;
}
