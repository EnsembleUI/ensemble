// manage Camera
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/widget/camera.dart';
import 'package:flutter/material.dart';

class CameraManager {
  Future<void> openCamera(BuildContext context, ShowCameraAction cameraAction , ScopeManager? scopeManager) async {
    
    Camera camera = Camera();
    if(cameraAction.id != null) {
      final previousAction = scopeManager?.dataContext.getContextById(cameraAction.id!) as Camera?;
      if (previousAction != null) camera = previousAction;
      scopeManager?.dataContext.addInvokableContext(cameraAction.id!, camera);
    }
  
    if (cameraAction.options != null) {
      cameraAction.options!['mode'] == null
          ? camera.setProperty('mode', CameraMode.both)
          : camera.setProperty('mode', c(cameraAction.options!['mode']));
      cameraAction.options!['initialCamera'] == null
          ? camera.setProperty('initialCamera', InitialCamera.back)
          : camera.setProperty(
              'initialCamera', i(cameraAction.options!['initialCamera']));
      cameraAction.options!['useGallery'] == null
          ? camera.setProperty('useGallery', true)
          : camera.setProperty(
              'useGallery', cameraAction.options!['useGallery']);
      cameraAction.options!['preview'] == null
          ? camera.setProperty('preview', false)
          : camera.setProperty('preview', cameraAction.options!['preview']);
      if (cameraAction.options!['maxCount'] != null) {
        camera.setProperty('maxCount', cameraAction.options!['maxCount']);
      }
      cameraAction.options!['maxCountMessage'] == null
          ? ''
          : camera.setProperty(
              'maxCountMessage', cameraAction.options!['maxCountMessage']);
      cameraAction.options!['imagePickerIcon'] == null
          ? ''
          : camera.setProperty(
              'imagePickerIcon', cameraAction.options!['imagePickerIcon']);
      cameraAction.options!['cameraRotateIcon'] == null
          ? ''
          : camera.setProperty(
              'cameraRotateIcon', cameraAction.options!['cameraRotateIcon']);
      cameraAction.options!['permissionDeniedMessage'] == null
          ? ''
          : camera.setProperty(
              'permissionDeniedMessage', cameraAction.options!['permissionDeniedMessage']);
      cameraAction.options!['nextButtonLabel'] == null
          ? ''
          : camera.setProperty(
              'nextButtonLabel', cameraAction.options!['nextButtonLabel']);                      
      cameraAction.options!['accessButtonLabel'] == null
          ? ''
          : camera.setProperty(
              'accessButtonLabel', cameraAction.options!['accessButtonLabel']); 
      cameraAction.options!['galleryButtonLabel'] == null
          ? ''
          : camera.setProperty(
              'galleryButtonLabel', cameraAction.options!['galleryButtonLabel']);
      cameraAction.onComplete == null
      ? (){} : camera.setProperty('onComplete', cameraAction.onComplete);
    }
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => camera,
      ),
    );

    if (cameraAction.id != null) {
      scopeManager?.dispatch(ModelChangeEvent(WidgetBindingSource(cameraAction.id!), camera));
    }
    
  }

  CameraMode c(String action) {
    CameraMode mode = CameraMode.both;
    if (action.toLowerCase() == 'photo') {
      return CameraMode.photo;
    } else if (action.toLowerCase() == 'video') {
      return CameraMode.video;
    }
    return mode;
  }

  InitialCamera i(String action) {
    InitialCamera mode = InitialCamera.back;
    if (action.toLowerCase() == 'back') {
      return InitialCamera.back;
    } else if (action.toLowerCase() == 'front') {
      return InitialCamera.front;
    }
    return mode;
  }
}

enum CameraMode {
  photo,
  video,
  both,
}

enum InitialCamera {
  back,
  front,
}
