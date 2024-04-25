import 'dart:developer';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/context_scope_widget.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// open a Modal Bottom Sheet
class ShowBottomModalAction extends EnsembleAction {
  ShowBottomModalAction(
      {super.initiator,
      super.inputs,
      this.body,
      this.styles,
      this.options,
      this.onDismiss});

  final dynamic body;
  final Map<String, dynamic>? styles;
  final Map<String, dynamic>? options;
  final EnsembleAction? onDismiss;

  // default height is size to content
  MainAxisSize getVerticalSize(scopeManager) =>
      MainAxisSize.values
          .from(scopeManager.dataContext.eval(styles?['verticalSize'])) ??
      MainAxisSize.min;

  MainAxisAlignment getVerticalAlignment(scopeManager) {
    var alignment = scopeManager.dataContext.eval(styles?['verticalAlignment']);
    switch (alignment) {
      case 'top':
        return MainAxisAlignment.start;
      case 'bottom':
        return MainAxisAlignment.end;
      default:
        // if verticalSize is min this doesn't matter, but center align if max
        return MainAxisAlignment.center;
    }
  }

  // default width is stretching 100%
  CrossAxisAlignment getHorizontalSize(scopeManager) {
    var size = MainAxisSize.values
            .from(scopeManager.dataContext.eval(styles?['horizontalSize'])) ??
        MainAxisSize.max;
    return size == MainAxisSize.min
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.stretch;
  }

  Alignment? getHorizontalAlignment(scopeManager) {
    var alignment =
        scopeManager.dataContext.eval(styles?['horizontalAlignment']);
    switch (alignment) {
      case 'start':
        return Alignment.centerLeft;
      case 'center':
        return Alignment.center;
      case 'end':
        return Alignment.centerRight;
      default:
        return null;
    }
  }

  Color? getBarrierColor(scopeManager) =>
      Utils.getColor(scopeManager.dataContext.eval(styles?['barrierColor']));

  // default background is the dialog background
  Color? getBackgroundColor(scopeManager) =>
      Utils.getColor(scopeManager.dataContext.eval(styles?['backgroundColor']));

  int? getTopBorderRadius(scopeManager) => Utils.optionalInt(
      scopeManager.dataContext.eval(styles?['topBorderRadius']));

  bool getEnableDrag(scopeManager) =>
      Utils.getBool(scopeManager.dataContext.eval(styles?['enableDrag']),
          fallback: true);

  factory ShowBottomModalAction.from({Invokable? initiator, Map? payload}) {
    dynamic body = payload?['body'] ?? payload?['widget'];
    if (payload == null || body == null) {
      throw LanguageError(
          "${ActionType.showBottomModal.name} requires a body widget.");
    }
    return ShowBottomModalAction(
        initiator: initiator,
        inputs: Utils.getMap(payload['inputs']),
        body: body,
        styles: Utils.getMap(payload['styles']),
        options: Utils.getMap(payload['options']),
        onDismiss: EnsembleAction.fromYaml(payload['onDismiss']));
  }

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    if (body == null) return Future.value(null);

    // verticalSize: min | max
    // verticalAlignment: top | center | bottom
    // horizontalSize: min | max
    // horizontalAlignment: start | center | end

    // topRadius: 15
    // backgroundColor
    // barrierColor

    var topRadius =
        Radius.circular(getTopBorderRadius(scopeManager)?.toDouble() ?? 16);
    var horizontalAlignment = getHorizontalAlignment(scopeManager);
    var widget = scopeManager.buildWidgetFromDefinition(body);

    var bodyWidget = Material(
      type: MaterialType.transparency,
      elevation: 16,
      child: Container(
          decoration: BoxDecoration(
              color: getBackgroundColor(scopeManager) ??
                  Theme.of(context).dialogBackgroundColor,
              borderRadius:
                  BorderRadius.only(topLeft: topRadius, topRight: topRadius)),
          child: Column(
              // vertical
              mainAxisSize: getVerticalSize(scopeManager),
              mainAxisAlignment: getVerticalAlignment(scopeManager),

              // horizontal
              crossAxisAlignment: getHorizontalSize(scopeManager),
              children: [
                // account for the bottom notch
                SafeArea(
                  bottom: false,
                    child: horizontalAlignment != null
                        ? Align(alignment: horizontalAlignment, child: widget)
                        : widget)
              ])),
    );

    showModalBottomSheet(
      context: context,
      // disable the default bottom sheet styling since we use our own
      backgroundColor: Colors.transparent,
      elevation: 16,

      barrierColor: getBarrierColor(scopeManager),
      isScrollControlled: true,
      enableDrag: getEnableDrag(scopeManager),
      // padding to account for the keyboard when we have input widgets inside the modal
      builder: (modalContext) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          // have a bottom modal scope widget so we can close the modal
          child: BottomModalScopeWidget(
            rootContext: modalContext,
            // create a new Data Scope since the bottom modal is placed in a different context tree (directly under MaterialApp)
            child: DataScopeWidget(
                scopeManager: scopeManager.createChildScope(),
                child: bodyWidget),
          )),
    ).then((payload) {
      if (onDismiss != null) {
        return ScreenController().executeActionWithScope(
            context, scopeManager, onDismiss!,
            event: EnsembleEvent(null, data: payload));
      }
    });
    return Future.value(null);
  }
}

/// Dismiss the Bottom Modal (if the context is a descendant, no-op otherwise)
class DismissBottomModalAction extends EnsembleAction {
  DismissBottomModalAction({this.payload});

  Map? payload;

  factory DismissBottomModalAction.from({Map? payload}) =>
      DismissBottomModalAction(payload: payload?['payload']);

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) {
    BuildContext? bottomModalContext =
        BottomModalScopeWidget.getRootContext(context);
    if (bottomModalContext != null) {
      return Navigator.maybePop(
          bottomModalContext, scopeManager.dataContext.eval(payload));
    }
    return Navigator.maybePop(context, scopeManager.dataContext.eval(payload));
  }
}

/// a wrapper InheritedWidget for its descendant to look up the root modal context to close it
class BottomModalScopeWidget extends InheritedWidget {
  const BottomModalScopeWidget(
      {super.key, required super.child, required this.rootContext});

  // this is the context root of the modal
  final BuildContext rootContext;

  @override
  bool updateShouldNotify(covariant BottomModalScopeWidget oldWidget) {
    return oldWidget.rootContext != rootContext;
  }

  static BuildContext? getRootContext(BuildContext context) {
    BottomModalScopeWidget? wrapperWidget =
        context.dependOnInheritedWidgetOfExactType<BottomModalScopeWidget>();
    return wrapperWidget?.rootContext;
  }
}
