import 'package:ensemble/framework/action.dart';
import 'package:flutter/material.dart';

import 'notification/notification_base.dart'
    if (dart.library.io) 'notification/notification_mobile.dart'
    if (dart.library.js) 'notification/notification_web.dart';

final notificationUtils = NotificationUtilsBase();

abstract class NotificationUtilsBase {
  BuildContext? context;
  EnsembleAction? onRemoteNotification;
  EnsembleAction? onRemoteNotificationOpened;

  factory NotificationUtilsBase() {
    return getObject();
  }

  Future<bool?> initNotifications();

  Future<void> showNotification(
    String? title,
    String? body, {
    String? imageUrl,
    String? payload,
  });

  void handleRemoteNotification();

  void handleRemoteNotificationOpened();

  Future<void> showProgressNotification(int progress, {int? notificationId});

  Future<bool?> hasPermission();
}
