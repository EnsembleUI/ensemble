import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

abstract class CameraManager {
  Future<bool?> hasPermission();
  Future<void> openCamera(BuildContext context, ShowCameraAction cameraAction,
      ScopeManager? scopeManager);
}

class CameraManagerStub extends CameraManager {
  @override
  Future<bool?> hasPermission() {
    return Future.value(false);
  }

  @override
  Future<void> openCamera(BuildContext context, ShowCameraAction cameraAction,
      ScopeManager? scopeManager) {
    throw ConfigError(
        "Camera Service is not enabled. Please review the Ensemble documentation.");
  }
}
