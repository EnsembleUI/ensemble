import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  bool success = true;

  // Define the camera module statements
  final cameraStatements = {
    'importStatements': [
      {
        'statement': "import 'package:ensemble_camera/camera_manager.dart'",
        'regex': toRegexPattern(
            "import 'package:ensemble_camera/camera_manager.dart'"),
      },
      {
        'statement': "import 'package:ensemble_camera/qr_code_scanner.dart';",
        'regex': toRegexPattern(
            "import 'package:ensemble_camera/qr_code_scanner.dart';"),
      }
    ],
    'useStatements': [
      {
        'statement': 'static const useCamera = true;',
        'regex': r'static\s+const\s+useCamera\s*=\s*(true|false);',
      }
    ],
    'registerStatements': [
      {
        'statement':
            'GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());',
        'regex': toRegexPattern(
            'GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());'),
      },
      {
        'statement': 'GetIt.I.registerSingleton<EnsembleQRCodeScanner>(',
        'regex':
            toRegexPattern('GetIt.I.registerSingleton<EnsembleQRCodeScanner>('),
      },
      {
        'statement':
            '    EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));',
        'regex': toRegexPattern(
            '    EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));'),
      },
    ],
    'pubspecDependencies': [
      {
        'statement': '''
ensemble_camera:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/camera
''',
        'regex':
            r'#\s*ensemble_camera:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/camera',
      }
    ],
  };

  // Define Android and iOS permissions for the camera
  final androidPermissions = [
    '<uses-permission android:name="android.permission.CAMERA" />',
  ];

  final iOSPermissions = [
    {
      'paramKey': '--camera_description',
      'key': 'NSCameraUsageDescription',
    }
  ];

  // Update the ensemble_modules.dart file
  try {
    updateEnsembleModules(
        ensembleModulesFilePath,
        cameraStatements['importStatements']!,
        cameraStatements['registerStatements']!,
        cameraStatements['useStatements']!);
  } catch (e) {
    print(e);
    success = false;
  }

  // Update the pubspec.yaml file
  try {
    updatePubspec(pubspecFilePath, cameraStatements['pubspecDependencies']!);
  } catch (e) {
    print(e);
    success = false;
  }

  // Add the camera permission to AndroidManifest.xml
  if (platforms.contains('android')) {
    try {
      updateAndroidPermissions(androidManifestFilePath, androidPermissions);
    } catch (e) {
      print('Error updating AndroidManifest.xml: $e');
      success = false;
    }
  }

  // Add the camera usage description to the iOS Info.plist file
  if (platforms.contains('ios')) {
    try {
      updateIOSPermissions(iosInfoPlistFilePath, iOSPermissions, arguments);
    } catch (e) {
      print('Error updating Info.plist: $e');
      success = false;
    }
  }

  if (success) {
    print('Camera module enabled successfully for ${platforms.join(', ')}! 🎉');
  }
}
