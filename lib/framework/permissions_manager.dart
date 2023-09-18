import 'package:ensemble/framework/stub/camera_manager.dart';
import 'package:ensemble/framework/stub/contacts_manager.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';

class PermissionsManager {
  static final PermissionsManager _instance = PermissionsManager._internal();
  PermissionsManager._internal();
  factory PermissionsManager() {
    return _instance;
  }

  Future<bool?> hasPermission(Permission type) async {
    bool? status;

    switch (type) {
      case Permission.notification:
        // firebase messaging does NOT work on Web's html-renderer
        if (kIsWeb) {
          status = await notificationUtils.hasPermission();
        } else {
          // use Firebase for status check all other platforms
          var settings =
              await FirebaseMessaging.instance.getNotificationSettings();
          switch (settings.authorizationStatus) {
            case AuthorizationStatus.authorized:
            case AuthorizationStatus.provisional:
              status = true;
              break;
            case AuthorizationStatus.denied:
              status = false;
              break;
            case AuthorizationStatus.notDetermined:
            default:
              status = null;
              break;
          }
        }
      case Permission.location:
        final locationPermission = await Geolocator.checkPermission();
        switch (locationPermission) {
          case LocationPermission.always:
          case LocationPermission.whileInUse:
            status = true;
            break;
          case LocationPermission.denied:
          case LocationPermission.deniedForever:
            status = false;
            break;
          case LocationPermission.unableToDetermine:
          default:
            status = null;
            break;
        }
      case Permission.contacts:
        try {
          final granted = await GetIt.I<ContactManager>().requestPermission();
          status = granted;
        } catch (_) {
          status = null;
          break;
        }
      case Permission.camera:
        try {
          final granted = await GetIt.I<CameraManager>().hasPermission();
          status = granted;
        } catch (_) {
          status = null;
          break;
        }
      default:
        return Future.value(status);
    }
    return Future.value(status);
  }
}

enum Permission {
  notification,
  location,
  contacts,
  camera,
}
