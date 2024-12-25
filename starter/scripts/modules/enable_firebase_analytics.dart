import 'dart:io';

import '../utils.dart';
import '../utils/firebase_utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');
  String enableConsoleLogs =
      getArgumentValue(arguments, 'enableConsoleLogs') ?? 'true';

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_firebase_analytics/firebase_analytics.dart';",
      "GetIt.I.registerSingleton<LogProvider>(FirebaseAnalyticsProvider());",
      "import 'dart:io';",
      "import 'package:flutter/foundation.dart';",
    ],
    'useStatements': [
      'static const useFirebaseAnalytics = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_firebase_analytics:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/firebase_analytics''',
      'regex':
          r'#\s*ensemble_firebase_analytics:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/firebase_analytics',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Generate Firebase configuration based on platform
    // updateFirebaseInitialization(platforms, arguments);
    updateFirebaseConfig(platforms, arguments);
    updateAnalyticsConfig(enableConsoleLogs);

    if (platforms.contains('android')) {
      addClasspathDependency(
          "classpath 'com.google.gms:google-services:4.3.15'");
      addPluginDependency("apply plugin: 'com.google.gms.google-services'");
      addImplementationDependency(
          "implementation 'com.google.firebase:firebase-analytics'");
      addImplementationDependency(
          "implementation platform('com.google.firebase:firebase-bom:32.7.0')");
      addSettingsPluginDependency(
          'id "com.google.gms.google-services" version "4.3.15" apply false');
    }

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    print(
        'Firebase Analytics module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
