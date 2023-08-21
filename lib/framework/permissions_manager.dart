import 'package:ensemble/util/notification_utils.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class PermissionsManager {
  static final PermissionsManager _instance = PermissionsManager._internal();
  PermissionsManager._internal();
  factory PermissionsManager() {
    return _instance;
  }

  Future<bool?> hasPermission(Permission type) async {
    bool? status;
    if (type == Permission.notification) {
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
    }
    return Future.value(status);
  }
}

enum Permission {
  notification,
}
