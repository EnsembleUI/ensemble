import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);
  String qrCodeScannerEnabled =
      getArgumentValue(arguments, 'qrcode_enabled') ?? 'true';

  final cameraStatements = {
    'moduleStatements': [
      "import 'package:ensemble_camera/camera_manager.dart';",
      "GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());",
      if (qrCodeScannerEnabled == 'true') ...[
        "import 'package:ensemble_camera/qr_code_scanner.dart';",
        "GetIt.I.registerSingleton<EnsembleQRCodeScanner>(",
        "     EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));",
      ],
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
      ref: main
      path: modules/camera''',
      'regex':
          r'#\s*ensemble_camera:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/camera',
    }
  ];

  final iOSPermissions = [
    {
      'key': 'camera_description',
      'value': 'NSCameraUsageDescription',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      ensembleModulesFilePath,
      cameraStatements['moduleStatements']!,
      cameraStatements['useStatements']!,
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecFilePath, pubspecDependencies);

    // Add the camera permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(androidManifestFilePath, permissions: [
        '<uses-permission android:name="android.permission.CAMERA" />'
      ]);
    }

    // Add the camera usage description to the iOS Info.plist file
    if (platforms.contains('ios')) {
      updateIOSPermissions(iosInfoPlistFilePath, iOSPermissions, arguments);
    }

    print('Camera module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
