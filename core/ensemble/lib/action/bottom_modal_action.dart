import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/context_scope_widget.dart';
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
      styles,
      options,
      this.onDismiss})
      : _styles = styles,
        _options = options;

  final dynamic body;
  final Map<String, dynamic>? _styles;
  final Map<String, dynamic>? _options;
  final EnsembleAction? onDismiss;

  bool _enableDrag(scopeManager) =>
      Utils.getBool(scopeManager.dataContext.eval(_options?['enableDrag']),
          fallback: true);

  bool _enableDragHandler(scopeManager) => Utils.getBool(
      scopeManager.dataContext.eval(_options?['enableDragHandler']),
      fallback: false);

  Color? _backgroundColor(scopeManager) => Utils.getColor(
      scopeManager.dataContext.eval(_styles?['backgroundColor']));

  Color? _barrierColor(scopeManager) =>
      Utils.getColor(scopeManager.dataContext.eval(_styles?['barrierColor']));

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
    Widget? widget;
    if (body != null) {
      widget = scopeManager.buildWidgetFromDefinition(body);
    }

    if (widget != null) {
      showModalBottomSheet(
        context: context,
        backgroundColor: _backgroundColor(scopeManager),
        barrierColor: _barrierColor(scopeManager),
        isScrollControlled: true,
        enableDrag: _enableDrag(scopeManager),
        showDragHandle: _enableDragHandler(scopeManager),
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: ContextScopeWidget(rootContext: context, child: widget!),
        ),
      ).then((payload) {
        if (onDismiss != null) {
          return ScreenController().executeActionWithScope(
              context, scopeManager, onDismiss!,
              event: EnsembleEvent(null, data: payload));
        }
      });
    }
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
        ContextScopeWidget.getRootContext(context);
    if (bottomModalContext != null) {
      return Navigator.maybePop(
          bottomModalContext, scopeManager.dataContext.eval(payload));
    }
    return Navigator.maybePop(context, scopeManager.dataContext.eval(payload));
  }
}
