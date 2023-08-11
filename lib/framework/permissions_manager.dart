import 'package:firebase_messaging/firebase_messaging.dart';

class PermissionsManager {
  static final PermissionsManager _instance = PermissionsManager._internal();
  PermissionsManager._internal();
  factory PermissionsManager() {
    return _instance;
  }

  Future<bool?> hasPermission(Permission type) async {
    bool? status;
    if (type == Permission.notification) {
      var settings = await FirebaseMessaging.instance.getNotificationSettings();
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
    return Future.value(status);
  }



}

enum Permission {
  notification,
}