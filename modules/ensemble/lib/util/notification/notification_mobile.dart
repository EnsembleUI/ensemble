import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/notification_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../notification_utils.dart';

NotificationUtilsBase getObject() => NotificationUtilsMobile();

class NotificationUtilsMobile implements NotificationUtilsBase {
  @override
  BuildContext? context;

  @override
  EnsembleAction? onRemoteNotification;

  @override
  EnsembleAction? onRemoteNotificationOpened;

  final FlutterLocalNotificationsPlugin localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  Future<bool?> initNotifications() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    await localNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        NotificationManager().handleNotification(details.payload ?? '');
      },
    );

    return _requestPermissions();
  }

  Future<bool> _requestPermissions() async {
    if (Platform.isIOS) {
      final granted = await localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return granted ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          localNotificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      bool? granted =
          await androidImplementation?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  @override
  Future<void> showNotification(
    String? title,
    String? body, {
    String? imageUrl,
    String? payload,
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
      payload: payload,
    );
  }

  @override
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
  Future<bool?> hasPermission() {
    // we check for permission on Native using Firebase, so no-op here
    return Future.value(null);
  }
}
