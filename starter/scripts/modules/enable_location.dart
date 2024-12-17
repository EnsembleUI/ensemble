import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_location/location_module.dart';",
      "GetIt.I.registerSingleton<LocationModule>(LocationModuleImpl());",
    ],
    'useStatements': [
      'static const useLocation = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_location:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/location''',
      'regex':
          r'#\s*ensemble_location:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/location',
    }
  ];

  final androidPermissions = [
    '<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />',
  ];

  final iOSPermissions = [
    {
      'key': 'inUseLocationDescription',
      'value': 'NSLocationWhenInUseUsageDescription',
    },
    {
      'key': 'alwaysUseLocationDescription',
      'value': 'NSLocationAlwaysUsageDescription',
    },
    {
      'key': 'locationDescription',
      'value': 'NSLocationAlwaysAndWhenInUseUsageDescription'
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Add the location permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: androidPermissions);
    }

    // Add the location usage description to the iOS Info.plist file
    if (platforms.contains('ios')) {
      updateIOSPermissions(iOSPermissions, arguments);
    }

    print(
        'Location module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
