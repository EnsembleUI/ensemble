import 'dart:io';

import '../utils.dart';
import '../utils/firebase_utils.dart';

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
    if (platforms.contains('android') || platforms.contains('ios')) {
      updateEnsembleModules(
        statements['moduleStatements'],
        statements['useStatements'],
      );
    }

    // Generate Firebase configuration based on platform
    // updateFirebaseInitialization(platforms, arguments);
    updateFirebaseConfig(platforms, arguments);

    if (platforms.contains('android')) {
      addClasspathDependency(
          "classpath 'com.google.gms:google-services:4.3.15'");
      addPluginDependency("apply plugin: 'com.google.gms.google-services'");
      addSettingsPluginDependency(
          'id "com.google.gms.google-services" version "4.3.15" apply false');
      addImplementationDependency(
          "implementation platform('com.google.firebase:firebase-bom:32.7.0')");
    }

    // Configure Android-specific settings
    if (platforms.contains('android')) {
      updateAndroidPermissions(
          permissions: androidPermissions, metaData: notificationsMetaData);
    }

    // Configure iOS-specific settings
    if (platforms.contains('ios')) {
      updateRunnerEntitlements(
        module: 'notifications',
      );
    }

    print(
        'Notifications module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
