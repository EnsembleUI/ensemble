import 'package:ensemble/action/face_camera_actions.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

abstract class FaceCameraManager {
  Future<bool?> hasPermission();
  Future<void> openFaceCamera(BuildContext context, ShowFaceCameraAction action,
      ScopeManager? scopeManager);
}

class FaceCameraManagerStub extends FaceCameraManager {
  @override
  Future<bool?> hasPermission() {
    return Future.value(false);
  }

  @override
  Future<void> openFaceCamera(BuildContext context, ShowFaceCameraAction action,
      ScopeManager? scopeManager) {
    throw ConfigError(
        "Face Camera Service is not enabled. Please review the Ensemble documentation.");
  }
}
