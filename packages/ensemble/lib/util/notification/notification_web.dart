import 'dart:developer';

import 'dart:html';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:flutter/material.dart' show BuildContext;

NotificationUtilsBase getObject() => NotificationUtils();

class NotificationUtils implements NotificationUtilsBase {
  @override
  BuildContext? context;

  @override
  EnsembleAction? onRemoteNotification;

  @override
  EnsembleAction? onRemoteNotificationOpened;

  @override
  void handleRemoteNotification() {
    if (context != null && onRemoteNotification != null) {
      ScreenController().executeAction(context!, onRemoteNotification!);
    } else {
      log('No context or action to handle remote notification');
    }
  }

  @override
  void handleRemoteNotificationOpened() {
    if (context != null && onRemoteNotificationOpened != null) {
      ScreenController().executeAction(context!, onRemoteNotificationOpened!);
    } else {
      log('No context or action to handle remote notification');
    }
  }

  @override
  Future<bool?> initNotifications() async {
    var permission = Notification.permission;
    if (permission != 'granted') {
      permission = await Notification.requestPermission();
    }
    return permission == 'granted';
  }

  @override
  Future<void> showNotification(String? title, String? body,
      {String? imageUrl}) async {
    var permission = Notification.permission;
    if (permission == 'granted') {
      Notification(title ?? '', body: body);
    }
  }

  @override
  Future<void> showProgressNotification(int progress, {int? notificationId}) {
    throw UnimplementedError();
  }

  @override
  Future<bool?> hasPermission() {
    bool? status;
    switch (Notification.permission) {
      case 'granted':
        status = true;
        break;
      case 'denied':
        status = false;
        break;
      case 'default':
      default:
        break;
    }
    return Future.value(status);
  }
}
