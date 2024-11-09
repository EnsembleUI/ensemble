import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  bool? hasGoogleMaps =
      getArgumentValue(arguments, 'google_maps')?.toLowerCase() == 'true';
  String? googleMapsApiKeyAndroid = getArgumentValue(
      arguments, 'google_maps_api_key_android',
      required: hasGoogleMaps && platforms.contains('android'));
  String? googleMapsApiKeyIOS = getArgumentValue(
      arguments, 'google_maps_api_key_ios',
      required: hasGoogleMaps && platforms.contains('ios'));
  String? googleMapsApiKeyWeb = getArgumentValue(
    arguments,
    'google_maps_api_key_web',
    required: hasGoogleMaps && platforms.contains('web'),
  );

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

    // Update Google Maps API key if available
    if (hasGoogleMaps == true) {
      if (platforms.contains('android') && googleMapsApiKeyAndroid != null) {
        updatePropertiesFile('googleMapsAPIKey', googleMapsApiKeyAndroid);
      }
      if (platforms.contains('ios') && googleMapsApiKeyIOS != null) {
        updateAppDelegateForGoogleMaps(googleMapsApiKeyIOS);
      }

      if (platforms.contains('web') && googleMapsApiKeyWeb != null) {
        updateHtmlFile('</head>',
            '<script src="https://maps.googleapis.com/maps/api/js?key=$googleMapsApiKeyWeb"></script>');
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
