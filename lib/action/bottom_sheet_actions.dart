import 'package:collection/collection.dart';
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
class ShowBottomSheetAction extends EnsembleAction {
  ShowBottomSheetAction({
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

  factory ShowBottomSheetAction.from({Invokable? initiator, Map? payload}) {
    dynamic body = payload?['body'] ?? payload?['widget'];
    if (payload == null || body == null) {
      throw LanguageError(
          "${ActionType.showBottomSheet.name} requires a body widget.");
    }
    return ShowBottomSheetAction(
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

  bool isSnap(scopeManager) =>
      Utils.optionalBool(
          eval(payload["scrollOptions"]?["snap"], scopeManager)) ??
      false;

  List<double>? additionalSnaps(scopeManager) => Utils.getList<double>(
      eval(payload["scrollOptions"]?["additionalViewportSnaps"], scopeManager));

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
            child: BottomSheetScopeWidget(
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

      bool useSnap = isSnap(scopeManager);
      List<double>? snaps = additionalSnaps(scopeManager)
          ?.where((item) => item > minViewport && item < maxViewport)
          .toList();
      snaps?.sort();

      // On platforms with a mouse (Web/desktop), there is no min/maxViewport due to platform consistency,
      // so the height will be fixed to initialViewport, and content will just scroll within it.
      // https://docs.flutter.dev/release/breaking-changes/default-scroll-behavior-drag
      return DraggableScrollableSheet(
          expand: false,
          minChildSize: minViewport,
          maxChildSize: maxViewport,
          initialChildSize: initialViewport,
          snap: useSnap,
          snapSizes: useSnap ? snaps : null,
          builder: (context, scrollController) =>
              buildRootContainer(scopeManager, context,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: widget,
                  ),
                  isScrollable: true));
    }
    return buildRootContainer(scopeManager, context,
        child: widget, isScrollable: false);
  }

  // This is the root container where all the root styling happen
  Widget buildRootContainer(ScopeManager scopeManager, BuildContext context,
      {required Widget child, required bool isScrollable}) {
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
        // stretch width 100%. Note that Flutter's bottom sheet has a width constraint on Web/Desktop so it may not take 100% on wide screen
        width: double.infinity,
        // if scrollable we have to stretch to the DraggableScrollableSheet's height which is variable
        height: isScrollable ? double.infinity : null,
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
class DismissBottomSheetAction extends EnsembleAction {
  DismissBottomSheetAction({this.payload});

  Map? payload;

  factory DismissBottomSheetAction.from({Map? payload}) =>
      DismissBottomSheetAction(payload: payload?['payload']);

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager,
      {DataContext? dataContext}) {
    BuildContext? bottomSheetContext =
        BottomSheetScopeWidget.getRootContext(context);
    if (bottomSheetContext != null) {
      return Navigator.maybePop(
          bottomSheetContext, scopeManager.dataContext.eval(payload));
    }
    return Navigator.maybePop(context, scopeManager.dataContext.eval(payload));
  }
}

/// a wrapper InheritedWidget for its descendant to look up the Sheet's root context to close it
class BottomSheetScopeWidget extends InheritedWidget {
  const BottomSheetScopeWidget(
      {super.key, required super.child, required this.rootContext});

  // this is the context root of the modal
  final BuildContext rootContext;

  @override
  bool updateShouldNotify(covariant BottomSheetScopeWidget oldWidget) {
    return oldWidget.rootContext != rootContext;
  }

  static BuildContext? getRootContext(BuildContext context) {
    BottomSheetScopeWidget? wrapperWidget =
        context.dependOnInheritedWidgetOfExactType<BottomSheetScopeWidget>();
    return wrapperWidget?.rootContext;
  }
}
