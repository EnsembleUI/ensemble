import 'dart:developer';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notificationUtils = _NotificationUtils();

class _NotificationUtils {
  BuildContext? context;
  EnsembleAction? onRemoteNotification;
  EnsembleAction? onRemoteNotificationOpened;

  final FlutterLocalNotificationsPlugin localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await localNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> showNotification(
    String? title,
    String? body, {
    String? imageUrl,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'channel_id',
      'channel_name',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
    );
    const DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails();
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await localNotificationsPlugin.show(
      0,
      title ?? 'Notification Title',
      body ?? 'Notification Body',
      platformChannelSpecifics,
      payload: 'notification_payload',
    );
  }

  Future<void> showProgressNotification(
    int progress, {
    int? notificationId,
  }) async {
    final androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'upload_channel_id',
      'File Upload',
      channelDescription: 'Notification channel for file uploads',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progress,
    );

    const iosPlatformChannelSpecifics = DarwinNotificationDetails(
      subtitle: 'Uploading...',
    );

    final platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iosPlatformChannelSpecifics,
    );

    await localNotificationsPlugin.show(
      notificationId ?? 0,
      'File Upload',
      progress == 100 ? 'Uploaded' : 'Progress $progress %',
      platformChannelSpecifics,
    );
  }

  void handleRemoteNotification() {
    if (context != null && onRemoteNotification != null) {
      ScreenController().executeAction(context!, onRemoteNotification!);
    } else {
      log('No context or action to handle remote notification');
    }
  }

  void handleRemoteNotificationOpened() {
    if (context != null && onRemoteNotificationOpened != null) {
      ScreenController().executeAction(context!, onRemoteNotificationOpened!);
    } else {
      log('No context or action to handle remote notification');
    }
  }
}
