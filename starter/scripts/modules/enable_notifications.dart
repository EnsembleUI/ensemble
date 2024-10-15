import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  final statements = {
    'moduleStatements': [
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

    // Generate Firebase configuration based on platform
    updateFirebaseInitialization(platforms, arguments);

    // Configure Android-specific settings
    if (platforms.contains('android')) {
      updateAndroidPermissions(androidManifestFilePath,
          permissions: androidPermissions, metaData: notificationsMetaData);
    }

    // Configure iOS-specific settings
    if (platforms.contains('ios')) {
      updateRunnerEntitlements(
        entitlementsFilePath: runnerEntitlementsPath,
        module: 'notifications',
      );
    }

    print(
        'Notifications module enabled successfully for ${platforms.join(', ')}! 🎉 Please make sure to add google-services.json for Android and GoogleService-Info.plist for iOS at the root of the Android and iOS directories respectively to enable Firebase messaging.');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
