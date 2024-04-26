import 'dart:io';

import 'package:ensemble/framework/config.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

abstract class EnsembleWidget<C extends EnsembleController>
    extends StatefulWidget {
  const EnsembleWidget(this.controller, {super.key});

  final C controller;

  List<String> passthroughSetters() => [];
}

abstract class EnsembleWidgetState<W extends EnsembleWidget> extends State<W> {
  void _update() {
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_update);
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  ScopeManager? getScopeManager() => DataScopeWidget.getScope(context);

  @override
  Widget build(BuildContext context) {
    if (widget.controller is EnsembleWidgetController) {
      EnsembleWidgetController widgetController =
          widget.controller as EnsembleWidgetController;

      Widget rtn = buildWidget(context);

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
      }

      // final isTestMode = EnvConfig().isTestMode;

      // if (isTestMode &&
      //     widgetController.testId != null &&
      //     widgetController.testId!.isNotEmpty) {
      //   rtn = Semantics(
      //     identifier: '${widgetController.testId!}: ',
      //     child: rtn,
      //   );
      // }

      return rtn;
    }
    throw LanguageError("Wrong usage of widget controller!");
  }

  /// build your widget here
  Widget buildWidget(BuildContext context);
}
