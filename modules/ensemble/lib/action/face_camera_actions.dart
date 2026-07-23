import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/face_camera_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

/// Ensemble action that opens the face-camera capture flow.
class ShowFaceCameraAction extends EnsembleAction {
  /// Creates a [ShowFaceCameraAction] action.
  ShowFaceCameraAction({
    Invokable? initiator,
    this.options,
    this.id,
    this.onComplete,
    this.onClose,
    this.onCapture,
    this.onError,
    this.overlayWidget,
    this.loadingWidget,
  }) : super(initiator: initiator);
  /// Provider-specific options passed through from the action payload.
  final Map<String, dynamic>? options;
  /// Identifier used to store results, target an existing resource, or correlate callbacks.
  String? id;
  /// Action executed after the operation completes successfully.
  EnsembleAction? onComplete;
  /// Action executed when the native flow closes.
  EnsembleAction? onClose;
  /// Action executed after media is captured.
  EnsembleAction? onCapture;
  /// Action executed when the operation fails.
  EnsembleAction? onError;
  /// Optional widget definition rendered as an overlay in the capture flow.
  dynamic overlayWidget;
  /// Optional widget definition rendered while the native flow loads.
  dynamic loadingWidget;

  /// Creates a [ShowFaceCameraAction] from a YAML or map action payload.
  factory ShowFaceCameraAction.fromYaml({Invokable? initiator, Map? payload}) {
    Map<String, dynamic> options = Utils.getMap(payload?['options']) ?? {};
    payload?.forEach((key, value) {
      if (![
        'options',
        'id',
        'onComplete',
        'onClose',
        'onCapture',
        'onError',
        'overlayWidget',
        'loadingWidget'
      ].contains(key)) {
        options[key.toString()] = value;
      }
    });

    return ShowFaceCameraAction(
      initiator: initiator,
      options: options.isNotEmpty ? options : null,
      id: Utils.optionalString(payload?['id']),
      onComplete: EnsembleAction.from(payload?['onComplete']),
      onClose: EnsembleAction.from(payload?['onClose']),
      onCapture: EnsembleAction.from(payload?['onCapture']),
      onError: EnsembleAction.from(payload?['onError']),
      overlayWidget: payload?['overlayWidget'],
      loadingWidget: payload?['loadingWidget'],
    );
  }
  /// Runs this action and performs the show face camera operation.
  @override
  Future<dynamic> execute(
      BuildContext context, ScopeManager scopeManager) async {
    try {
      await GetIt.I<FaceCameraManager>()
          .openFaceCamera(context, this, scopeManager);
    } catch (e) {
      if (onError != null) {
        await ScreenController().executeAction(context, onError!,
            event: EnsembleEvent(null, error: e.toString()));
      }
    }
  }
}
