import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  // Get Firebase configuration values
  String? androidApiKey = getArgumentValue(arguments, 'android_api_key',
      required: platforms.contains('android'));
  String? androidAppId = getArgumentValue(arguments, 'android_app_id',
      required: platforms.contains('android'));
  String? androidMessagingSenderId = getArgumentValue(
      arguments, 'android_messaging_sender_id',
      required: platforms.contains('android'));
  String? androidProjectId = getArgumentValue(arguments, 'android_project_id',
      required: platforms.contains('android'));

  String? iosApiKey = getArgumentValue(arguments, 'ios_api_key',
      required: platforms.contains('ios'));
  String? iosAppId = getArgumentValue(arguments, 'ios_app_id',
      required: platforms.contains('ios'));
  String? iosMessagingSenderId = getArgumentValue(
      arguments, 'ios_messaging_sender_id',
      required: platforms.contains('ios'));
  String? iosProjectId = getArgumentValue(arguments, 'ios_project_id',
      required: platforms.contains('ios'));

  String? webApiKey = getArgumentValue(arguments, 'web_api_key',
      required: platforms.contains('web'));
  String? webAppId = getArgumentValue(arguments, 'web_app_id',
      required: platforms.contains('web'));
  String? webAuthDomain = getArgumentValue(arguments, 'web_auth_domain',
      required: platforms.contains('web'));
  String? webMessagingSenderId = getArgumentValue(
      arguments, 'web_messaging_sender_id',
      required: platforms.contains('web'));
  String? webProjectId = getArgumentValue(arguments, 'web_project_id',
      required: platforms.contains('web'));
  String? webStorageBucket = getArgumentValue(arguments, 'web_storage_bucket',
      required: platforms.contains('web'));
  String? webMeasurementId = getArgumentValue(arguments, 'web_measurement_id',
      required: platforms.contains('web'));

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble/util/utils.dart';",
      "import 'package:ensemble/framework/storage_manager.dart';",
      "import 'package:flutter/foundation.dart';",
      "import 'dart:io';",
    ],
    'useStatements': [
      'static const useNotifications = true;',
    ],
  };

  final androidPermissions = [
    '<uses-permission android:name="android.permission.CAMERA" />',
  ];

  const notificationsMetaData = [
    '<meta-data android:name="com.google.firebase.messaging.default_notification_icon" android:resource="@mipmap/ic_launcher" />'
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      ensembleModulesFilePath,
      statements['moduleStatements']!,
      statements['useStatements']!,
    );

    // Configure Android-specific settings
    if (platforms.contains('android')) {
      updateAndroidPermissions(androidManifestFilePath, androidPermissions);
      addMetaDataInAndroidManifest(
          androidManifestFilePath, notificationsMetaData);
    }

    // Configure iOS-specific settings
    if (platforms.contains('ios')) {
      updateRunnerEntitlements(
        entitlementsFilePath: runnerEntitlementsPath,
        module: 'notifications',
      );
    }

    // Generate Firebase configuration based on platform
    updateFirebaseInitialization(
      platforms,
      androidApiKey: androidApiKey,
      androidAppId: androidAppId,
      androidMessagingSenderId: androidMessagingSenderId,
      androidProjectId: androidProjectId,
      iosApiKey: iosApiKey,
      iosAppId: iosAppId,
      iosMessagingSenderId: iosMessagingSenderId,
      iosProjectId: iosProjectId,
      webApiKey: webApiKey,
      webAppId: webAppId,
      webAuthDomain: webAuthDomain,
      webMessagingSenderId: webMessagingSenderId,
      webProjectId: webProjectId,
      webStorageBucket: webStorageBucket,
      webMeasurementId: webMeasurementId,
    );

    print(
        'Notifications module enabled successfully for ${platforms.join(', ')}! 🎉 Please make sure to add google-services.json for Android and GoogleService-Info.plist for iOS at the root of the Android and iOS directories respectively to enable Firebase messaging.');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
