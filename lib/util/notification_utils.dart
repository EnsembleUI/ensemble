import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final notificationUtils = _NotificationUtils();

class _NotificationUtils {
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
}
