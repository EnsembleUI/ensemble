import 'dart:io';

import '../utils.dart';

Future<void> main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final cameraStatements = {
    'moduleStatements': [
      "import 'package:ensemble_camera/camera_manager.dart';",
      "GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());",
    ],
    'useStatements': [
      'static const useCamera = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_camera:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/camera''',
      'regex':
          r'#\s*ensemble_camera:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/camera',
    }
  ];

  final iOSPermissions = [
    {
      'key': 'cameraDescription',
      'value': 'NSCameraUsageDescription',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      cameraStatements['moduleStatements'],
      cameraStatements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Add the camera permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: [
        '<uses-permission android:name="android.permission.CAMERA" />'
      ]);
    }

    // Add the camera usage description to the iOS Info.plist file
    if (platforms.contains('ios')) {
      updateIOSPermissions(iOSPermissions, arguments);
    }

    print('Camera module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
