import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// open a Modal Bottom Sheet
class ShowBottomModalAction extends EnsembleAction {
  ShowBottomModalAction({
    super.initiator,
    super.inputs,
    required this.body,
    required this.payload,
    this.onDismiss,
  });

  static const defaultTopBorderRadius = Radius.circular(16);

  final Map payload;
  final dynamic body;
  final EnsembleAction? onDismiss;

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
        onDismiss: EnsembleAction.fromYaml(payload['onDismiss']),
        payload: payload);
  }

  EdgeInsets? margin(scopeManager) =>
      Utils.optionalInsets(eval(payload["styles"]?["margin"], scopeManager));

  EdgeInsets? padding(scopeManager) =>
      Utils.optionalInsets(eval(payload["styles"]?["padding"], scopeManager));

  EBorderRadius? borderRadius(scopeManager) => Utils.getBorderRadius(
      eval(payload["styles"]?["borderRadius"], scopeManager));

  bool useSafeArea(scopeManager) =>
      Utils.getBool(eval(payload["styles"]?["useSafeArea"], scopeManager),
          fallback: false);

  Color? getBarrierColor(scopeManager) =>
      Utils.getColor(eval(payload["styles"]?['barrierColor'], scopeManager));

  Color? getBackgroundColor(scopeManager) =>
      Utils.getColor(eval(payload["styles"]?['backgroundColor'], scopeManager));

  bool showDragHandle(scopeManager) =>
      Utils.getBool(eval(payload["styles"]?["showDragHandle"], scopeManager),
          fallback: true);

  Color? dragHandleColor(scopeManager) =>
      Utils.getColor(eval(payload["styles"]?["dragHandleColor"], scopeManager));

  bool? isScrollable(scopeManager) =>
      Utils.optionalBool(eval(payload["scrollable"], scopeManager));

  // scroll options
  double? _initialViewport(scopeManager) => Utils.optionalDouble(
      eval(payload["scrollOptions"]?["initialViewport"], scopeManager),
      min: 0,
      max: 1);

  double? _minViewport(scopeManager) => Utils.optionalDouble(
      eval(payload["scrollOptions"]?["minViewport"], scopeManager),
      min: 0,
      max: 1);

  double? _maxViewport(scopeManager) => Utils.optionalDouble(
      eval(payload["scrollOptions"]?["maxViewport"], scopeManager),
      min: 0,
      max: 1);

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    if (body != null) {
      showModalBottomSheet(
        context: context,
        // disable the default bottom sheet styling since we use our own
        backgroundColor: Colors.transparent,
        elevation: 0,
        showDragHandle: false,

        barrierColor: getBarrierColor(scopeManager),
        isScrollControlled: true,
        enableDrag: true,
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
                  child: getBodyWidget(scopeManager, context)),
            )),
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

  Widget getBodyWidget(ScopeManager scopeManager, BuildContext context) {
    var widget = scopeManager.buildWidgetFromDefinition(body);
    if (isScrollable(scopeManager) == true) {
      // fix the viewport numbers if used incorrectly
      double minViewport = _minViewport(scopeManager) ?? 0.25;
      double maxViewport = _maxViewport(scopeManager) ?? 1;
      if (minViewport > maxViewport) {
        // reset
        minViewport = 0.25;
        maxViewport = 1;
      }
      double initialViewport = _initialViewport(scopeManager) ?? 0.5;
      if (initialViewport < minViewport || initialViewport > maxViewport) {
        // to middle
        initialViewport = (minViewport + maxViewport) / 2.0;
      }

      return DraggableScrollableSheet(
          expand: false,
          minChildSize: minViewport,
          maxChildSize: maxViewport,
          initialChildSize: initialViewport,
          builder: (context, scrollController) =>
              buildRootContainer(scopeManager, context,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: widget,
                  )));
    }
    return buildRootContainer(scopeManager, context, child: widget);
  }

  // This is the root container where all the root styling happen
  Widget buildRootContainer(ScopeManager scopeManager, BuildContext context,
      {required Widget child}) {
    Widget rootWidget = Container(
        margin: margin(scopeManager),
        padding: padding(scopeManager),
        decoration: BoxDecoration(
            color: getBackgroundColor(scopeManager) ??
                Theme.of(context).dialogBackgroundColor,
            borderRadius: borderRadius(scopeManager)?.getValue() ??
                const BorderRadius.only(
                    topLeft: defaultTopBorderRadius,
                    topRight: defaultTopBorderRadius)),
        clipBehavior: Clip.antiAlias,
        width: double.infinity,
        // stretch width 100%
        child: useSafeArea(scopeManager) ? SafeArea(child: child) : child);
    if (showDragHandle(scopeManager)) {
      rootWidget = Stack(
        alignment: Alignment.topCenter,
        children: [rootWidget, _buildDragHandle(scopeManager)],
      );
    }
    return rootWidget;
  }

  Widget _buildDragHandle(ScopeManager scopeManager) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 32,
      height: 3,
      decoration: BoxDecoration(
        color: dragHandleColor(scopeManager) ?? Colors.grey[500],
        borderRadius: BorderRadius.circular(12),
      ),
    );
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
