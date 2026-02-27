import 'package:camera/camera.dart';
import 'package:ensemble/action/face_camera_actions.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/framework/stub/face_camera_manager.dart';
import 'package:face_camera/face_camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import './face_detection_camera.dart';

class FaceCameraManagerImpl extends FaceCameraManager {
  @override
  Future<bool?> hasPermission() async {
    bool? status;
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        status = true;
      } else {
        status = null;
      }
      return status;
    } catch (error) {
      status = false;
      return status;
    }
  }

  @override
  Future<void> openFaceCamera(BuildContext context, ShowFaceCameraAction action,
      ScopeManager? scopeManager) async {
    if (!kIsWeb) {
      await FaceCamera.initialize();
    }

    final camera = FaceDetectionCamera(
      onCapture: (file) async {
        // Pop the camera page once a capture has occurred.
        Navigator.pop(context);
        final fileJson = file?.toJson();
        // If an ID is provided and scopeManager exists, update dataContext and dispatch event.
        if (action.id != null && scopeManager != null) {
          scopeManager.dataContext.addDataContext({
            action.id!: {
              'files': [fileJson]
            }
          });
          scopeManager.dispatch(
            ModelChangeEvent(
              APIBindingSource(action.id!),
              {
                'files': [fileJson]
              },
            ),
          );
        }

        // Execute the onCapture action if provided.
        if (action.onCapture != null) {
          try {
            await ScreenController().executeAction(context, action.onCapture!);
          } on Exception catch (_) {}
        }
      },
      onError: (error) {
        // Close the camera page when an error occurs.
        Navigator.pop(context);

        if (action.onError != null) {
          ScreenController().executeAction(
            context,
            action.onError!,
            event: EnsembleEvent(null, error: error.toString()),
          );
        }
      },
    );

    // Set properties from options
    final options = action.options ?? {};
    for (var option in options.keys) {
      final value = scopeManager?.dataContext.eval(options[option]);
      camera.setProperty(option, value);
    }

    // Set properties from flat inputs
    final inputs = action.inputs ?? {};
    for (var input in inputs.keys) {
      final value = scopeManager?.dataContext.eval(inputs[input]);
      camera.setProperty(input, value);
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => camera),
    );
  }

  Widget? buildOverlayWidget(
      ScopeManager? scopeManager, ShowFaceCameraAction action) {
    Widget? overlayWidget;
    try {
      overlayWidget =
          scopeManager?.buildWidgetFromDefinition(action.overlayWidget);
      if (overlayWidget != null) {
        overlayWidget =
            DataScopeWidget(scopeManager: scopeManager!, child: overlayWidget);
      }
    } on Exception catch (e) {
      debugPrint(
          'Ensemble Face Camera: Error while building overlay widget $e');
    }
    return overlayWidget;
  }

  Widget? buildLoadingWidget(
      ScopeManager? scopeManager, ShowFaceCameraAction action) {
    Widget? loadingWidget;
    try {
      loadingWidget =
          scopeManager?.buildWidgetFromDefinition(action.loadingWidget);
      if (loadingWidget != null) {
        loadingWidget =
            DataScopeWidget(scopeManager: scopeManager!, child: loadingWidget);
      }
    } on Exception catch (e) {
      debugPrint(
          'Ensemble Face Camera: Error while building loading widget $e');
    }
    return loadingWidget;
  }
}
