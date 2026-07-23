import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/ensemble_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/**
 * Show a dialog
 */
/// Ensemble action that presents an Ensemble dialog.
class ShowDialogAction extends EnsembleAction {
  /// Creates a [ShowDialogAction] action.
  ShowDialogAction({
    super.initiator,
    required this.body,
    required this.dismissible,
    this.options,
    this.onDialogDismiss,
  });

  /// Widget or content body rendered by a toast, dialog, or bottom sheet.
  final dynamic body;
  /// Whether the user can dismiss the UI without completing the flow.
  final bool dismissible;
  /// Provider-specific options passed through from the action payload.
  final Map<String, dynamic>? options;
  /// Action executed when the dialog is dismissed.
  final EnsembleAction? onDialogDismiss;

  /// Creates a [ShowDialogAction] from a YAML or map action payload.
  factory ShowDialogAction.from({Invokable? initiator, Map? payload}) {
    if (payload == null ||
        (payload['body'] == null && payload['widget'] == null)) {
      throw LanguageError(
          "${ActionType.showDialog.name} requires the 'body' for the Dialog's content.");
    }
    return ShowDialogAction(
      initiator: initiator,
      body: Utils.maybeYamlMap(payload['body']) ??
          Utils.maybeYamlMap(payload['widget']),
      options: Utils.getMap(payload['options']),
      dismissible: Utils.getBool(payload['dismissible'], fallback: true),
      onDialogDismiss: payload['onDialogDismiss'] == null
          ? null
          : EnsembleAction.from(Utils.maybeYamlMap(payload['onDialogDismiss'])),
    );
  }

  /// Runs this action and builds and presents the configured dialog.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) {
    // get styles. TODO: make bindable
    Map<String, dynamic> dialogStyles = {};
    options?.forEach((key, value) {
      dialogStyles[key] = scopeManager.dataContext.eval(value);
    });

    bool useDefaultStyle = dialogStyles['style'] != 'none';
    BuildContext? dialogContext;

    showGeneralDialog(
        useRootNavigator: false,
        // use inner-most MaterialApp (our App) as root so theming is ours
        context: context,
        barrierDismissible: dismissible,
        barrierLabel: "Barrier",
        barrierColor: Colors.black54,
        // this has some transparency so the bottom shown through

        pageBuilder: (context, animation, secondaryAnimation) {
          // save a reference to the builder's context so we can close it programmatically
          dialogContext = context;
          scopeManager.openedDialogs.add(dialogContext!);

          return Align(
              alignment: Alignment(
                  Utils.getDouble(dialogStyles['horizontalOffset'],
                      min: -1, max: 1, fallback: 0),
                  Utils.getDouble(dialogStyles['verticalOffset'],
                      min: -1, max: 1, fallback: 0)),
              child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                      constraints: BoxConstraints(
                          minWidth: Utils.getDouble(dialogStyles['minWidth'],
                              fallback: 0),
                          maxWidth: Utils.getDouble(dialogStyles['maxWidth'],
                              fallback: double.infinity),
                          minHeight: Utils.getDouble(dialogStyles['minHeight'],
                              fallback: 0),
                          maxHeight: Utils.getDouble(dialogStyles['maxHeight'],
                              fallback: double.infinity)),
                      child: Container(
                          decoration: useDefaultStyle
                              ? const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(5)),
                                  boxShadow: <BoxShadow>[
                                      BoxShadow(
                                        color: Colors.white38,
                                        blurRadius: 5,
                                        offset: Offset(0, 0),
                                      )
                                    ])
                              : null,
                          margin:
                              useDefaultStyle ? const EdgeInsets.all(20) : null,
                          padding:
                              useDefaultStyle ? const EdgeInsets.all(20) : null,
                          child: DataScopeWidget(
                              scopeManager: scopeManager.createChildScope(),
                              child: SingleChildScrollView(
                                child: scopeManager
                                    .buildWidgetFromDefinition(body),
                              ))))));
        }).then((payload) {
      // remove the dialog context since we are closing them
      scopeManager.openedDialogs.remove(dialogContext);

      // callback when dialog is dismissed
      if (onDialogDismiss != null) {
        ScreenController().executeActionWithScope(
            context, scopeManager, onDialogDismiss!,
            event: EnsembleEvent(initiator, data: payload));
      }
    });
    return Future.value(null);
  }
}

/**
 * Dismiss a dialog. A payload can be passed to showDialog's onDismiss
 */
/// Ensemble action that closes a specific dialog or the active dialog.
class DismissDialogAction extends EnsembleAction {
  /// Creates a [DismissDialogAction] action.
  DismissDialogAction({super.initiator, this.payload});

  /// Raw action payload passed to the action implementation.
  final Map? payload;

  /// Creates a [DismissDialogAction] from a YAML or map action payload.
  factory DismissDialogAction.from({Invokable? initiator, Map? payload}) =>
      DismissDialogAction(
          initiator: initiator, payload: Utils.getMap(payload?['payload']));

  /// Runs this action and closes the active dialog.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async =>
      EnsembleUtils.dismissDialog(
        scopeManager.dataContext.eval(payload),
        context,
      );
}

/// Legacy action that closes every dialog tracked by the current scope.
///
/// Prefer [DismissDialogAction] for new definitions.
@Deprecated("use DismissDialogAction")
class CloseAllDialogsAction extends EnsembleAction {
  /// Runs this action and closes all active dialogs.
  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async {
    // Dialog dismiss callback also try to remove openedDialogs while we are
    // looping through, hence the copy
    List<BuildContext> dialogsCopy = List.from(scopeManager.openedDialogs);
    for (var dialogContext in dialogsCopy) {
      if (dialogContext.mounted) {
        await Navigator.maybePop(dialogContext);
      }
    }
    scopeManager.openedDialogs.clear();
    return Future.value(null);
  }
}