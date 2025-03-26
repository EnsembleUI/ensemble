library ensemble_camera;

// manage Camera
import 'package:camera/camera.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/stub/camera_manager.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:face_camera/face_camera.dart';

import './camera.dart';
import './face_detection_camera.dart';

const _optionMappings = {
  'mode': 'mode',
  'initialCamera': 'initialCamera',
  'allowGalleryPicker': 'allowGalleryPicker',
  'allowCameraRotate': 'allowCameraRotate',
  'allowFlashControl': 'allowFlashControl',
  'preview': 'preview',
  'maxCount': 'maxCount',
  'minCount': 'minCount',
  'permissionDeniedMessage': 'permissionDeniedMessage',
  'accessButtonLabel': 'accessButtonLabel',
  'galleryButtonLabel': 'galleryButtonLabel',
  'nextButtonLabel': 'nextButtonLabel',
  'cameraRotateIcon': 'cameraRotateIcon',
  'galleryPickerIcon': 'galleryPickerIcon',
  'focusIcon': 'focusIcon',
  'maxCountMessage': 'maxCountMessage',
  'minCountMessage': 'minCountMessage',
  'autoCaptureInterval': 'autoCaptureInterval',
  'enableMicrophone': 'enableMicrophone',
  'instantPreview': 'instantPreview',
  'captureOverlay': 'captureOverlay',
  'loadingWidget': 'loadingWidget',
  'faceDetection': 'faceDetection',
};

const _angleAssistOptions = {
  'assistAngleMessage': 'assistAngleMessage',
  'maxAngle': 'maxAngle',
  'minAngle': 'minAngle',
};

const _speedAssistOptions = {
  'assistSpeedMessage': 'assistSpeedMessage',
  'maxSpeed': 'maxSpeed',
};

class CameraManagerImpl extends CameraManager {
  @override
  Future<bool?> hasPermission() async {
    bool? status;
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        await CameraController(cameras[0], ResolutionPreset.max).initialize();
        status = true;
      } else {
        status = null;
      }
      return status;
    } catch (error) {
      if (error is CameraException) {
        switch (error.code) {
          // User denied the camera access request
          case 'CameraAccessDenied':
          // User has previously denied the camera access request
          case 'CameraAccessDeniedWithoutPrompt':
            status = false;
            break;
          case 'CameraAccessRestricted': // Parental Control
          default:
            status = null;
            break;
        }
      } else {
        status = null;
      }
      return status;
    }
  }

  Future<File?> convertXFile(XFile element) async {
    final bytes = kIsWeb ? await element.readAsBytes() : null;
    final fileSize = await element.length();
    File file = File(element.name, element.path.split('.').last, fileSize,
        element.path, bytes);
    return file;
  }

  @override
  Future<void> openCamera(BuildContext context, ShowCameraAction cameraAction,
      ScopeManager? scopeManager) async {
    final isDefault = Utils.getBool(
        scopeManager?.dataContext.eval(cameraAction.options?['default']),
        fallback: false);

    final faceDetection = Utils.getBool(
        scopeManager?.dataContext
            .eval(cameraAction.options?['faceDetection'])?['enabled'],
        fallback: false);

    if (isDefault && !kIsWeb) {
      await defaultCamera(context, cameraAction, scopeManager);
    } else if (faceDetection) {
      await faceDetectionCamera(context, cameraAction, scopeManager);
    } else {
      await bespokeCamera(context, cameraAction, scopeManager);
    }
  }

  Future<void> defaultCamera(BuildContext context,
      ShowCameraAction cameraAction, ScopeManager? scopeManager) async {
    final mode = Utils.getString(
        scopeManager?.dataContext.eval(cameraAction.options?['mode']),
        fallback: 'photo');

    final picker = ImagePicker();
    XFile? xFile;
    if (mode == 'video') {
      xFile = await picker.pickVideo(source: ImageSource.camera);
    } else if (mode == 'photo') {
      xFile = await picker.pickImage(source: ImageSource.camera);
    }

    if (xFile == null) return;
    final file = await convertXFile(xFile);
    if (file == null) return;

    if (cameraAction.id != null && scopeManager != null) {
      scopeManager.dataContext.addDataContext({
        cameraAction.id!: {
          'files': [file.toJson()]
        }
      });
    }
    if (cameraAction.id != null) {
      scopeManager?.dispatch(
        ModelChangeEvent(APIBindingSource(cameraAction.id!), {
          'files': [file.toJson()]
        }),
      );
    }
    if (cameraAction.onComplete != null) {
      try {
        // ignore: use_build_context_synchronously
        ScreenController().executeAction(context, cameraAction.onComplete!);
      } on Exception catch (_) {}
    }
  }

  Future<void> bespokeCamera(BuildContext context,
      ShowCameraAction cameraAction, ScopeManager? scopeManager) async {
    Widget? overlayWidget;
    Widget? loadingWidget;
    if (cameraAction.overlayWidget != null) {
      overlayWidget = buildOverlayWidget(scopeManager, cameraAction);
    }

    if (cameraAction.loadingWidget != null) {
      loadingWidget = buildLoadingWidget(scopeManager, cameraAction);
    }

    Camera camera = Camera(
      overlayWidget: overlayWidget,
      loadingWidget: loadingWidget,
      onCapture: cameraAction.onCapture == null
          ? null
          : () {
              ScreenController()
                  .executeAction(context, cameraAction.onCapture!);
            },
      onComplete: cameraAction.onComplete == null
          ? null
          : () {
              ScreenController()
                  .executeAction(context, cameraAction.onComplete!);
            },
      onError: cameraAction.onError == null
          ? null
          : (error) {
              ScreenController().executeAction(
                context,
                cameraAction.onError!,
                event: EnsembleEvent(
                  null,
                  error: error.toString(),
                ),
              );
            },
    );

    if (cameraAction.id != null) {
      final previousAction =
          scopeManager?.dataContext.getContextById(cameraAction.id!) as Camera?;
      if (previousAction != null) camera = previousAction;
      scopeManager?.dataContext.addInvokableContext(cameraAction.id!, camera);
    }

    if (cameraAction.options != null) {
      if (cameraAction.options!['assistAngle'] != null) {
        camera.setProperty('assistAngle', true);
        for (var option in cameraAction.options!['assistAngle'].keys) {
          final property = _angleAssistOptions[option];
          if (property != null) {
            camera.setProperty(
                property, cameraAction.options!['assistAngle']![option]);
          }
        }
      }

      if (cameraAction.options!['assistSpeed'] != null) {
        camera.setProperty('assistSpeed', true);
        for (var option in cameraAction.options!['assistSpeed'].keys) {
          final property = _speedAssistOptions[option];
          if (property != null) {
            camera.setProperty(
                property, cameraAction.options!['assistSpeed']![option]);
          }
        }
      }

      for (var option in cameraAction.options!.keys) {
        final property = _optionMappings[option];
        if (property != null) {
          final value =
              scopeManager?.dataContext.eval(cameraAction.options![option]);
          camera.setProperty(property, value);
        }
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => camera,
      ),
    );

    if (cameraAction.onClose != null) {
      try {
        // ignore: use_build_context_synchronously
        ScreenController().executeAction(context, cameraAction.onClose!);
      } catch (_) {}
    }

    if (cameraAction.id != null) {
      scopeManager?.dispatch(
          ModelChangeEvent(WidgetBindingSource(cameraAction.id!), camera));
    }
  }

  Future<void> faceDetectionCamera(BuildContext context,
      ShowCameraAction cameraAction, ScopeManager? scopeManager) async {
    if (!kIsWeb) {
      await FaceCamera.initialize();
    }

    final camera = FaceDetectionCamera(
      onCapture: (file) async {
        // Pop the camera page once a capture has occurred.
        Navigator.pop(context);
        final fileJson = file?.toJson();
        // If an ID is provided and scopeManager exists, update dataContext and dispatch event.
        if (cameraAction.id != null && scopeManager != null) {
          scopeManager.dataContext.addDataContext({
            cameraAction.id!: {
              'files': [fileJson]
            }
          });
          scopeManager.dispatch(
            ModelChangeEvent(
              APIBindingSource(cameraAction.id!),
              {
                'files': [fileJson]
              },
            ),
          );
        }

        // Execute the onCapture action if provided.
        if (cameraAction.onCapture != null) {
          try {
            await ScreenController()
                .executeAction(context, cameraAction.onCapture!);
          } on Exception catch (_) {}
        }
      },
      onError: (error) {
        // Close the camera page when an error occurs.
        Navigator.pop(context);

        if (cameraAction.onError != null) {
          ScreenController().executeAction(
            context,
            cameraAction.onError!,
            event: EnsembleEvent(null, error: error),
          );
        }
      },
    );

    final options = cameraAction.options ?? {};
    for (var option in options.keys) {
      final property = _optionMappings[option];
      if (property != null) {
        final value = scopeManager?.dataContext.eval(options[option]);
        camera.setProperty(property, value);
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => camera),
    );
  }

  Widget? buildOverlayWidget(
      ScopeManager? scopeManager, ShowCameraAction cameraAction) {
    Widget? overlayWidget;
    try {
      overlayWidget =
          scopeManager?.buildWidgetFromDefinition(cameraAction.overlayWidget);
      if (overlayWidget != null) {
        overlayWidget =
            DataScopeWidget(scopeManager: scopeManager!, child: overlayWidget);
      }
    } on Exception catch (e) {
      debugPrint('Ensemble Camera: Error while building overlay widget $e');
    }
    return overlayWidget;
  }

  Widget? buildLoadingWidget(
      ScopeManager? scopeManager, ShowCameraAction cameraAction) {
    Widget? loadingWidget;
    try {
      loadingWidget =
          scopeManager?.buildWidgetFromDefinition(cameraAction.loadingWidget);
      if (loadingWidget != null) {
        loadingWidget =
            DataScopeWidget(scopeManager: scopeManager!, child: loadingWidget);
      }
    } on Exception catch (e) {
      debugPrint('Ensemble Camera: Error while building loading widget $e');
    }
    return loadingWidget;
  }
}
