// manage Camera
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/widget/camera.dart';
import 'package:flutter/material.dart';

class CameraManager {
  // Singleton
  static final CameraManager _instance = CameraManager._internal();
  CameraManager._internal();
  factory CameraManager() {
    return _instance;
  }
    // open camera function to set properties
  void openCamera(BuildContext context, ShowCameraAction cameraAction) async {

    // if camera action option is null than create camera screen without any setter
    if (cameraAction.options == null) {
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CameraScreen(),
        ),
      );
    }
    // if camera action is not null 
    else {
    // camera instance is created for set properties to setter
    // if any other camera instance is created already automatically remove beacuse camera instance is dispose
    // when screen is close
     
      CameraScreen camera = CameraScreen();
      cameraAction.options!['mode'] == null
          ? camera.setProperty('mode', 'photo')
          : camera.setProperty('mode', cameraAction.options!['mode']);
      cameraAction.options!['initialCamera'] == null
          ? camera.setProperty('initialCamera', 'back')
          : camera.setProperty('initialCamera', cameraAction.options!['initialCamera']);
      cameraAction.options!['useGallery'] == null
          ? camera.setProperty('useGallery', true)
          : camera.setProperty('useGallery', cameraAction.options!['useGallery']);
      cameraAction.options!['preview'] == null
          ? camera.setProperty('preview', false)
          : camera.setProperty('preview', cameraAction.options!['preview']);
      cameraAction.options!['maxCount'] == null
          ? camera.setProperty('maxCount', 1)
          : camera.setProperty('maxCount', cameraAction.options!['maxCount']);      

      // when properties is set push on camera screen 
      // res is used when camera is close than return list of image
      final res = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => camera,
        ),
      );
    }
  }
}
