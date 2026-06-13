import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_wifi/ensemble_wifi.dart';",
      'GetIt.I.registerSingleton<WifiManager>(WifiManagerImpl());',
    ],
    'useStatements': [
      'static const useWifi = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_wifi:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/ensemble_wifi''',
      'regex':
          r'#\s*ensemble_wifi:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/ensemble_wifi',
    }
  ];

  final androidPermissions = [
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
  ];

  try {
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    updatePubspec(pubspecDependencies);

    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: androidPermissions);
    }

    if (platforms.contains('ios')) {
      final inUseLocationDescription = getArgumentValue(
            arguments, 'inUseLocationDescription') ??
          'Location access is required to connect to WiFi networks.';

      addPermissionDescriptionToInfoPlist(
        'NSLocationWhenInUseUsageDescription',
        inUseLocationDescription,
      );
      updateRunnerEntitlements(module: 'wifi');
    }

    print('WiFi module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
