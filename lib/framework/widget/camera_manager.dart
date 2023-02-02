// manage Camera
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/camera.dart';
import 'package:flutter/material.dart';

class CameraManager {
  // Singleton
  static final CameraManager _instance = CameraManager._internal();
  CameraManager._internal() {
    //
  }
  factory CameraManager() {
    return _instance;
  }
  // open camera function to set properties
  void openCamera(BuildContext context, ShowCameraAction cameraAction) async {
    CameraScreen camera = CameraScreen();
    if (camera.controller.cameracontroller != null) {
      if (camera.controller.cameracontroller!.value.isInitialized) {
        camera.controller.dispose();
        if (cameraAction.options == null) {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CameraScreen(),
            ),
          );
        }
        else {
          print('Check Else Condition');
          CameraScreen camera = CameraScreen();
          cameraAction.options!['mode'] == null
              ? camera.setProperty('mode', 'back')
              : camera.setProperty('mode', cameraAction.options!['mode']);
          // cameraAction.options!['mode'] != null ? camera.setProperty('mode', Utils.getString(cameraAction.options!['mode'], fallback: '')) : camera.setProperty('mode', 'photo');
          // cameraAction.options!['initialCamera'] != null ? camera.setProperty('initialCamera', Utils.getString(cameraAction.options!['initialCamera'], fallback: '')) : camera.setProperty('initialCamera', 'back');
          // cameraAction.options!['useGallery'] != null ? camera.setProperty('useGallery', Utils.getBool(cameraAction.options!['useGallery'], fallback: false)) : camera.setProperty('useGallery', true);
          // cameraAction.options!['preview'] != null ? camera.setProperty('preview', Utils.getBool(cameraAction.options!['preview'], fallback: false)) : camera.setProperty('preview', false);
          // cameraAction.options!['maxCount'] != null ? camera.setProperty('maxCount', Utils.getInt(cameraAction.options!['maxCount'], fallback: 0)) : camera.setProperty('maxCount', 1);
          final res = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CameraScreen(),
            ),
          );
          print('Check Result $res');
        }
      }
    }
    if (cameraAction.options == null) {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(),
        ),
      );
    }
    else {
      print('Check Else Condition');
      CameraScreen camera = CameraScreen();
      cameraAction.options!['mode'] == null
          ? camera.setProperty('mode', 'back')
          : camera.setProperty('mode', cameraAction.options!['mode']);
      // cameraAction.options!['mode'] != null ? camera.setProperty('mode', Utils.getString(cameraAction.options!['mode'], fallback: '')) : camera.setProperty('mode', 'photo');
      // cameraAction.options!['initialCamera'] != null ? camera.setProperty('initialCamera', Utils.getString(cameraAction.options!['initialCamera'], fallback: '')) : camera.setProperty('initialCamera', 'back');
      // cameraAction.options!['useGallery'] != null ? camera.setProperty('useGallery', Utils.getBool(cameraAction.options!['useGallery'], fallback: false)) : camera.setProperty('useGallery', true);
      // cameraAction.options!['preview'] != null ? camera.setProperty('preview', Utils.getBool(cameraAction.options!['preview'], fallback: false)) : camera.setProperty('preview', false);
      // cameraAction.options!['maxCount'] != null ? camera.setProperty('maxCount', Utils.getInt(cameraAction.options!['maxCount'], fallback: 0)) : camera.setProperty('maxCount', 1);
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(),
        ),
      );
      print('Check Result $res');
    }
  }
}
