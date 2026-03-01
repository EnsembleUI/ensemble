import 'dart:io';

import '../utils.dart';
import '../utils/firebase_utils.dart';

Future<void> main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_remote_config/remote_config.dart';",
      "GetIt.I.registerSingleton<RemoteConfig>(RemoteConfigImpl());",
    ],
    'useStatements': [
      'static const useRemoteConfig = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_remote_config:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/ensemble_remote_config''',
      'regex':
          r'#\s*ensemble_remote_config:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/ensemble_remote_config',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Generate Firebase configuration based on platform (Remote Config uses Firebase)
    updateFirebaseInitialization(platforms, arguments);
    updateFirebaseConfig(platforms, arguments);

    if (platforms.contains('android')) {
      addClasspathDependency(
          "classpath 'com.google.gms:google-services:4.3.15'");
      addPluginDependency("id 'com.google.gms.google-services'");
      addImplementationDependency(
          "implementation platform('com.google.firebase:firebase-bom:32.7.0')");
      addSettingsPluginDependency(
          'id "com.google.gms.google-services" version "4.3.15" apply false');
    }

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    print(
        'Firebase Remote Config module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
