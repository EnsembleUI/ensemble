import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_activity/ensemble_activity.dart';",
      'GetIt.I.registerSingleton<ActivityManager>(ActivityManagerImpl());',
    ],
    'useStatements': [
      'static const useActivity = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_activity:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/ensemble_activity''',
      'regex':
          r'#\s*ensemble_activity:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/ensemble_activity',
    }
  ];

  final androidPermissions = [
    // Required for activity recognition (Android 10+)
    '<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />',
  ];

  final iOSPermissions = [
    {
      'key': 'motionDescription',
      'value': 'NSMotionUsageDescription',
    },
  ];
  final iOSAdditionalSettings = [
    {
      // Required if you want motion updates while app is in background
      'key': 'UIBackgroundModes',
      'value': ['motion'],
      'isArray': true,
    },
  ];

  try {
    // Update ensemble_modules.dart
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update pubspec.yaml
    updatePubspec(pubspecDependencies);

    // Android permissions
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: androidPermissions);
    }

    // iOS permissions (no background modes)
    if (platforms.contains('ios')) {
      updateIOSPermissions(
        iOSPermissions,
        arguments,
        additionalSettings: iOSAdditionalSettings,
      );
    }

    print(
        'Activity recognition module enabled successfully for ${platforms.join(', ')}! 🚶');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
