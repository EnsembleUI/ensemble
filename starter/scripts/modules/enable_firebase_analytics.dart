import 'dart:io';

import '../utils.dart';
import '../utils/firebase_utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

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
      ref: main
      path: modules/firebase_analytics''',
      'regex':
          r'#\s*ensemble_firebase_analytics:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/firebase_analytics',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      ensembleModulesFilePath,
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Generate Firebase configuration based on platform
    updateFirebaseInitialization(platforms, arguments, firebaseAnalytics: true);

    // Update the pubspec.yaml file
    updatePubspec(pubspecFilePath, pubspecDependencies);

    print(
        'Firebase Analytics module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
