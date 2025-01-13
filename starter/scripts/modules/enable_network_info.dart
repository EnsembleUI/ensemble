import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');
  String? preciseLocationDescription =
      getArgumentValue(arguments, 'preciseLocationDescription');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_network_info/network_info.dart';",
      'GetIt.I.registerSingleton<NetworkInfoManager>(NetworkInfoImpl());',
    ],
    'useStatements': [
      'static const useNetworkInfo = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_network_info:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/ensemble_network_info''',
      'regex':
          r'#\s*ensemble_network_info:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/ensemble_network_info',
    }
  ];

  final androidPermissions = [
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
    '<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />'
  ];

  final iOSPermissions = [
    {
      'key': 'inUseLocationDescription',
      'value': 'NSLocationWhenInUseUsageDescription',
    },
    {
      'key': 'alwaysUseLocationDescription',
      'value': 'NSLocationAlwaysAndWhenInUseUsageDescription',
    },
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Add required permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: androidPermissions);
    }

    // Add required permissions to Info.plist
    if (platforms.contains('ios')) {
      if (preciseLocationDescription == null ||
          preciseLocationDescription.isEmpty) {
        print("Error: Precise location description is missing.");
        exit(1);
      }
      updateIOSPermissions(iOSPermissions, arguments);
      addPermissionDescriptionToInfoPlist(
        'NSLocationTemporaryUsageDescriptionDictionary',
        {'PreciseLocation': preciseLocationDescription},
        isDict: true,
      );
      updateRunnerEntitlements(module: 'networkInfo');
    }

    print(
        'Network Info module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
