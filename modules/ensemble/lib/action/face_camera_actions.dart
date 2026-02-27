import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/face_camera_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

class ShowFaceCameraAction extends EnsembleAction {
  ShowFaceCameraAction({
    Invokable? initiator,
    this.options,
    this.inputs,
    this.id,
    this.onComplete,
    this.onClose,
    this.onCapture,
    this.onError,
    this.overlayWidget,
    this.loadingWidget,
  }) : super(initiator: initiator);
  final Map<String, dynamic>? options;
  final Map<String, dynamic>? inputs;
  String? id;
  EnsembleAction? onComplete;
  EnsembleAction? onClose;
  EnsembleAction? onCapture;
  EnsembleAction? onError;
  dynamic overlayWidget;
  dynamic loadingWidget;

  factory ShowFaceCameraAction.fromYaml({Invokable? initiator, Map? payload}) {
    Map<String, dynamic> inputs = {};
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
        inputs[key.toString()] = value;
      }
    });

    return ShowFaceCameraAction(
      initiator: initiator,
      options: Utils.getMap(payload?['options']),
      inputs: inputs.isNotEmpty ? inputs : null,
      id: Utils.optionalString(payload?['id']),
      onComplete: EnsembleAction.from(payload?['onComplete']),
      onClose: EnsembleAction.from(payload?['onClose']),
      onCapture: EnsembleAction.from(payload?['onCapture']),
      onError: EnsembleAction.from(payload?['onError']),
      overlayWidget: payload?['overlayWidget'],
      loadingWidget: payload?['loadingWidget'],
    );
  }
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
