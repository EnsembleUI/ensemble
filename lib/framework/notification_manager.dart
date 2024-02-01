import 'dart:convert';
import 'dart:developer';
import 'dart:io' show Platform;

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Firebase Push Notification handler
class NotificationManager {
  static final NotificationManager _instance = NotificationManager._internal();

  NotificationManager._internal();

  factory NotificationManager() => _instance;

  var _init = false;

  // Store the last known device token
  String? deviceToken;

  Future<void> init(
      {FirebasePayload? payload,
      Future<void> Function(RemoteMessage)?
          backgroundNotificationHandler}) async {
    if (!_init) {
      /// if payload is not passed, Firebase configuration files
      /// are required to be added manualy to iOS and Android
      await Firebase.initializeApp(
        options: payload?.getFirebaseOptions(),
      );
      _initListener(
          backgroundNotificationHandler: backgroundNotificationHandler);
      // local notification initialization
      notificationUtils.initNotifications();
      _init = true;
    }
  }

  /// get the device token. This guarantees the token (if available)
  /// is the latest correct token
  Future<String?> getDeviceToken() async {
    String? deviceToken;
    try {
      // request permission
      NotificationSettings settings =
          await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // on iOS we need to get APNS token first
        if (!kIsWeb && Platform.isIOS) {
          await FirebaseMessaging.instance.getAPNSToken();
        }

        // get device token
        deviceToken = await FirebaseMessaging.instance.getToken();
        return deviceToken;
      }
    } on Exception catch (e) {
      log('Error getting device token: ${e.toString()}');
    }
    return null;
  }

  void _initListener(
      {Future<void> Function(RemoteMessage)? backgroundNotificationHandler}) {
    /// listen for token changes and store a copy
    FirebaseMessaging.instance.onTokenRefresh.listen((String newToken) {
      deviceToken = newToken;
    });

    /// This is when the app is in the foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      Ensemble.externalDataContext.addAll({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data
      });
      // _handleNotification(message);
      notificationUtils.showNotification(
        message.notification?.title,
        message.notification?.body,
        payload: jsonEncode(message.toMap()),
      );
    });

    /// when the app is in the background, we can't run UI logic.
    /// But we can support a callback to the main class for custom logic
    if (backgroundNotificationHandler != null) {
      FirebaseMessaging.onBackgroundMessage(backgroundNotificationHandler);
    }

    /// This is when the app is in the background and the user taps on the notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      Ensemble.externalDataContext.addAll({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data
      });
      handleNotification(message);
    });
  }

  // TODO: framework should call this automatically
  void initGetInitialMessage() {
    // This is called when the user taps on the notification and the app is opened from the terminated state
    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message == null) return;

      Ensemble.externalDataContext.addAll({
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data
      });
      // notification will be executed AFTER the home screen has finished rendering
      Ensemble().addPushNotificationCallback(
          method: () => handleNotification(message));
    }).catchError((err) {
      // ignore: avoid_print
      print(
          "Failed to get the remote notification's initial message. Ignoring ...");
    });
  }

  Future<void> handleNotification(RemoteMessage message) async {
    Map<String, dynamic> payload = {
      'notificationPayload': {
        'title': message.notification?.title,
        'body': message.notification?.body,
        'data': message.data,
      }
    };
    if (message.data['screenId'] != null ||
        message.data['screenName'] != null) {
      ScreenController().navigateToScreen(Utils.globalAppKey.currentContext!,
          screenId: message.data['screenId'],
          screenName: message.data['screenName'],
          pageArgs: {
            // backward compatibility
            ...message.data,
            ...payload,
          });
    } else {
      ScreenController().navigateToScreen(Utils.globalAppKey.currentContext!,
          pageArgs: payload);
    }
  }
}

/// abstract to just the absolute must need Firebase options
class FirebasePayload {
  FirebasePayload(
      {required this.apiKey,
      required this.projectId,
      required this.messagingSenderId,
      required this.appId});

  String apiKey;
  String projectId;
  String messagingSenderId;
  String appId;

  FirebaseOptions getFirebaseOptions() => FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId);
}
