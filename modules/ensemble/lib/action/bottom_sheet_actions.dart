import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/ensemble_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// open a Modal Bottom Sheet
class ShowBottomSheetAction extends EnsembleAction with HasStyles, Invokable {
  /// Creates a [ShowBottomSheetAction] action.
  ShowBottomSheetAction({
    super.initiator,
    super.inputs,
    required this.body,
    required this.payload,
    this.onDismiss,
  });

  /// Default top corner radius for modal bottom sheets.
  static const defaultTopBorderRadius = Radius.circular(16);
  /// Default height of the bottom-sheet drag handle.
  static const dragHandleHeight = 3.0;
  /// Vertical margin around the bottom-sheet drag handle.
  static const dragHandleVerticalMargin = 10.0;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  /// Raw action payload passed to the action implementation.
  final Map payload;
  /// Widget or content body rendered by a toast, dialog, or bottom sheet.
  final dynamic body;
  /// Action executed when the presented sheet or modal is dismissed.
  final EnsembleAction? onDismiss;

  /// Creates a [ShowBottomSheetAction] from a YAML or map action payload.
  factory ShowBottomSheetAction.from({Invokable? initiator, Map? payload}) {
    dynamic body = payload?['body'] ?? payload?['widget'];
    if (payload == null || body == null) {
      throw LanguageError(
          "${ActionType.showBottomSheet.name} requires a body widget.");
    }
    // Create a mutable copy of payload so we can update styles after resolution
    final mutablePayload = Map<String, dynamic>.from(payload);
    return ShowBottomSheetAction(
        initiator: initiator,
        inputs: Utils.getMap(payload['inputs']),
        body: body,
        onDismiss: EnsembleAction.from(payload['onDismiss']),
        payload: mutablePayload);
  }

  /// Evaluates bottom-sheet margin from the current data context.
  EdgeInsets? margin(scopeManager) =>
      Utils.optionalInsets(eval(payload["styles"]?["margin"], scopeManager));

  /// Evaluates bottom-sheet padding from the current data context.
  EdgeInsets? padding(scopeManager) =>
      Utils.optionalInsets(eval(payload["styles"]?["padding"], scopeManager));

  /// Evaluates bottom-sheet border radius from the current data context.
  EBorderRadius? borderRadius(scopeManager) => Utils.getBorderRadius(
      eval(payload["styles"]?["borderRadius"], scopeManager));

  /// Whether the bottom sheet should respect safe-area insets.
  bool useSafeArea(scopeManager) =>
      Utils.getBool(eval(payload["styles"]?["useSafeArea"], scopeManager),
          fallback: false);

  /// Evaluates the modal barrier color.
  Color? getBarrierColor(scopeManager) =>
      Utils.getColor(eval(payload["styles"]?['barrierColor'], scopeManager));

  /// Evaluates the bottom-sheet background color.
  Color? getBackgroundColor(scopeManager) =>
      Utils.getColor(eval(payload["styles"]?['backgroundColor'], scopeManager));

  /// Whether the bottom sheet should show a drag handle.
  bool showDragHandle(scopeManager) =>
      Utils.getBool(eval(payload["styles"]?["showDragHandle"], scopeManager),
          fallback: true);

  /// Evaluates the bottom-sheet drag handle color.
  Color? dragHandleColor(scopeManager) =>
      Utils.getColor(eval(payload["styles"]?["dragHandleColor"], scopeManager));

  /// Whether the bottom-sheet body should be scroll controlled.
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

  /// Whether draggable bottom sheet snapping is enabled.
  bool isSnap(scopeManager) =>
      Utils.optionalBool(
          eval(payload["scrollOptions"]?["snap"], scopeManager)) ??
      false;

  /// Additional snap sizes for a draggable bottom sheet.
  List<double>? additionalSnaps(scopeManager) => Utils.getList<double>(
      eval(payload["scrollOptions"]?["additionalViewportSnaps"], scopeManager));

  /// Runs this action and builds and presents the configured bottom sheet.
  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    if (body != null) {
      final body = getBodyWidget(scopeManager, context);
      // Get the APIProviders from the parent context to pass down to the modal
      final apiProviders = APIProviders.of(context);
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
          builder: (modalContext) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalContext).viewInsets.bottom,
              ),
              // Wrap in APIProviders so the modal content has access to API providers (e.g., Firestore)
              child: APIProviders(
                providers: apiProviders.providers,
                child: DataScopeWidget(
                    scopeManager: scopeManager.createChildScope(), child: body),
              ),
            );
          }).then((payload) {
        if (onDismiss != null) {
          return ScreenController().executeActionWithScope(
              context, scopeManager, onDismiss!,
              event: EnsembleEvent(null, data: payload));
        }
      });
    }
    return Future.value(null);
  }

  /// Builds the widget used as bottom-sheet body content.
  Widget getBodyWidget(ScopeManager scopeManager, BuildContext context) {
    // We have to handle the BottomSheet's padding directly around the widget,
    // such that it is inside the Scrollable area to be able to move up and down.
    var sheetPadding = padding(scopeManager) ?? EdgeInsets.zero;

    // account for the drag handle
    if (showDragHandle(scopeManager)) {
      var additionalPaddingTop =
          dragHandleVerticalMargin * 2 + dragHandleHeight;
      sheetPadding =
          sheetPadding.copyWith(top: sheetPadding.top + additionalPaddingTop);
    }

    var widget = Padding(
        padding: sheetPadding,
        child: scopeManager.buildWidgetFromDefinition(body));

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
          expand: true,
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

  /// Builds the root container around bottom-sheet content.
  Widget buildRootContainer(ScopeManager scopeManager, BuildContext context,
      {required Widget child, required bool isScrollable}) {
    Widget rootWidget = Container(
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
    // This is the Margin of the bottom sheet.
    // Padding will be handled separately inside the scrollable area
    return Padding(
        padding: margin(scopeManager) ?? EdgeInsets.zero, child: rootWidget);
  }

  Widget _buildDragHandle(ScopeManager scopeManager) {
    return Container(
      margin: const EdgeInsets.only(top: dragHandleVerticalMargin),
      width: 32,
      height: dragHandleHeight,
      decoration: BoxDecoration(
        color: dragHandleColor(scopeManager) ?? Colors.grey[500],
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Dismiss the Bottom Modal (if the context is a descendant, no-op otherwise)
class DismissBottomSheetAction extends EnsembleAction {
  /// Creates a [DismissBottomSheetAction] action.
  DismissBottomSheetAction({super.initiator, this.payload});

  /// Raw action payload passed to the action implementation.
  Map? payload;

  /// Creates a [DismissBottomSheetAction] from a YAML or map action payload.
  factory DismissBottomSheetAction.from({Invokable? initiator, Map? payload}) =>
      DismissBottomSheetAction(
          initiator: initiator, payload: Utils.getMap(payload?['payload']));

  /// Runs this action and closes the active bottom sheet.
  @override
  Future<bool> execute(BuildContext context, ScopeManager scopeManager) {
    return EnsembleUtils.dismissBottomSheet(
      scopeManager.dataContext.eval(payload),
      context,
    );
  }
}
