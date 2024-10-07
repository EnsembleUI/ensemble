import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);
  bool? hasGoogleMaps =
      getArgumentValue(arguments, 'google_maps')?.toLowerCase() == 'true';
  String? googleMapsApiKey = getArgumentValue(arguments, 'google_maps_api_key',
      required: hasGoogleMaps);

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
      ref: main
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
      'key': 'in_use_location_description',
      'value': 'NSLocationWhenInUseUsageDescription',
    },
    {
      'key': 'always_use_location_description',
      'value': 'NSLocationAlwaysUsageDescription',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      ensembleModulesFilePath,
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecFilePath, pubspecDependencies);

    // Add the location permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(androidManifestFilePath, androidPermissions);
    }

    // Add the location usage description to the iOS Info.plist file
    if (platforms.contains('ios')) {
      updateIOSPermissions(iosInfoPlistFilePath, iOSPermissions, arguments);
    }

    // Update Google Maps API key if available
    if (hasGoogleMaps == true && googleMapsApiKey != null) {
      updatePropertiesFile(
          ensemblePropertiesFilePath, 'googleMapsAPIKey', googleMapsApiKey);
      if (platforms.contains('ios')) {
        updateAppDelegateForGoogleMaps(appDelegatePath, googleMapsApiKey);
      }

      if (platforms.contains('web')) {
        updateHtmlFile(webIndexFilePath, '</head>',
            '<script src="https://maps.googleapis.com/maps/api/js?key=$googleMapsApiKey"></script>');
      }
    }

    print(
        'Location module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
