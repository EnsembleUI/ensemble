import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/data_context.dart';
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
class ShowDialogAction extends EnsembleAction {
  ShowDialogAction({
    super.initiator,
    required this.body,
    required this.dismissible,
    this.options,
    this.onDialogDismiss,
  });

  final dynamic body;
  final bool dismissible;
  final Map<String, dynamic>? options;
  final EnsembleAction? onDialogDismiss;

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
class DismissDialogAction extends EnsembleAction {
  DismissDialogAction({super.initiator, this.payload});

  final Map? payload;

  factory DismissDialogAction.from({Invokable? initiator, Map? payload}) =>
      DismissDialogAction(
          initiator: initiator, payload: Utils.getMap(payload?['payload']));

  @override
  Future execute(BuildContext context, ScopeManager scopeManager) async =>
      EnsembleUtils.dismissDialog(scopeManager.dataContext.eval(payload));
}

/**
 * This class is legacy and technically not correct. You can't save the
 * BuildContext to be removed later as BuildContext can change at any time
 */
@Deprecated("use DismissDialogAction")
class CloseAllDialogsAction extends EnsembleAction {
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