import 'dart:io';

import 'package:ensemble/framework/action.dart' as action;
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/config.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/studio_debugger.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:yaml/yaml.dart';

/// base mixin for Ensemble Container (e.g Column)
mixin UpdatableContainer<T extends Widget> {
  void initChildren({List<WidgetModel>? children, ItemTemplate? itemTemplate});
}

/// Deprecated. Use [EnsembleWidgetState] instead
/// base class for widgets that want to participate in Ensemble layout
abstract class WidgetState<W extends HasController> extends BaseWidgetState<W> {
  ScopeManager? scopeManager;

  @override
  void changeState() {
    super.changeState();
    // dispatch changes, so anything binding to this will be notified
    if (widget.controller.lastSetterProperty != null) {
      if (scopeManager != null &&
          widget is Invokable &&
          (widget as Invokable).id != null) {
        scopeManager!.dispatch(ModelChangeEvent(
            WidgetBindingSource((widget as Invokable).id!,
                property: widget.controller.lastSetterProperty!.key),
            widget.controller.lastSetterProperty!.value));
      }
      widget.controller.lastSetterProperty = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    scopeManager =
        DataScopeWidget.getScope(context) ?? PageGroupWidget.getScope(context);
  }

  @override
  void dispose() {
    if (widget is Invokable) {
      scopeManager?.removeBindingListeners(widget as Invokable);
    }
    super.dispose();
  }

  void resolveStylesIfUnresolved(BuildContext context) {
    if (widget.controller is HasStyles) {
      ScopeManager? scopeManager = DataScopeWidget.getScope(context) ??
          PageGroupWidget.getScope(context);
      Invokable? invokable;
      if (widget.controller is Invokable) {
        invokable = widget.controller as Invokable;
      } else if (widget is Invokable) {
        invokable = widget as Invokable;
      }
      if (scopeManager != null && invokable != null) {
        (widget.controller as HasStyles)
            .resolveStyles(scopeManager, invokable, context);
      }
    }
  }

  /// build your widget here
  Widget buildWidget(BuildContext context);

  @override
  Widget build(BuildContext context) {
    resolveStylesIfUnresolved(context);
    Widget rtn = buildWidget(context);
    if (widget.controller is WidgetController) {
      WidgetController widgetController = widget.controller as WidgetController;

      if (widgetController.elevation != null) {
        rtn = Material(
            elevation: widgetController.elevation?.toDouble() ?? 0,
            shadowColor: widgetController.elevationShadowColor,
            borderRadius: widgetController.elevationBorderRadius?.getValue(),
            child: rtn);
      }

      // in Web, capture the pointer if overlay on htmlelementview like Maps
      if (widgetController.captureWebPointer == true) {
        rtn = PointerInterceptor(child: rtn);
      }

      // wrap inside Align if specified
      if (widgetController.alignment != null) {
        rtn = Align(alignment: widgetController.alignment!, child: rtn);
      }

      // handle visibility
      if (widgetController.visibilityTransitionDuration != null) {
        rtn = AnimatedOpacity(
            opacity: widgetController.visible != false ? 1 : 0,
            duration: widgetController.visibilityTransitionDuration!,
            child: rtn);
      }
      // only wrap around Visibility if visible flag is specified,
      // since we don't want this on all widgets unnecessary
      else if (widgetController.visible != null) {
        rtn = Visibility(visible: widgetController.visible!, child: rtn);
      }

      // Note that Positioned or expanded below has to be used directly inside
      // Stack and FlexBox, respectively. They should be the last widget returned.
      if (widgetController.hasPositions()) {
        if (StudioDebugger().debugMode) {
          rtn = StudioDebugger().assertHasStackWrapper(rtn, context);
        }
        rtn = Positioned(
            top: widgetController.stackPositionTop?.toDouble(),
            bottom: widgetController.stackPositionBottom?.toDouble(),
            left: widgetController.stackPositionLeft?.toDouble(),
            right: widgetController.stackPositionRight?.toDouble(),
            child: rtn);
      } else if (widgetController.flex != null ||
          widgetController.flexMode != null) {
        rtn = StudioDebugger().assertHasFlexBoxParent(context, rtn);

        if (widgetController.flexMode == null ||
            widgetController.flexMode == FlexMode.expanded) {
          rtn = Expanded(flex: widgetController.flex ?? 1, child: rtn);
        } else if (widgetController.flexMode == FlexMode.flexible) {
          rtn = Flexible(flex: widgetController.flex ?? 1, child: rtn);
        }
        // don't do anything for FlexMode.none
      } else if (widgetController.expanded == true) {
        if (StudioDebugger().debugMode) {
          rtn = StudioDebugger().assertHasColumnRowFlexWrapper(rtn, context);
        }

        /// Important notes:
        /// 1. If the Column/Row is scrollable, putting Expanded on the child will cause layout exception
        /// 2. If Column/Row is inside a parent without height/width constraint, it will collapse its size.
        ///    So if we put Expanded on the Column's child, layout exception will occur
        rtn = Expanded(child: rtn);
      }

      final isTestMode = EnvConfig().isTestMode;

      if (isTestMode &&
          (widgetController.testId != null || widgetController.id != null)) {
        rtn = Semantics(
          label: widgetController.testId ?? widgetController.id,
          child: rtn,
        );
      }
    }
    return rtn;
  }
}

/// some of our widgets use LayoutBuilder to detect if their parent has
/// infinite width/height to properly respond (Input widgets inside Row
/// requires expanded=true). However some container (e.g. DataTable) requires
/// all its children to return the intrinsic width/height to properly render.
/// We just need to expose the hierarchy chain so we can properly handle
/// various situations
class RequiresChildWithIntrinsicDimension extends InheritedWidget {
  const RequiresChildWithIntrinsicDimension({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}

class RequiresRowColumnFlexWidget extends InheritedWidget {
  const RequiresRowColumnFlexWidget({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}

class RequireStackWidget extends InheritedWidget {
  const RequireStackWidget({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
