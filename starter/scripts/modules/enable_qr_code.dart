import 'dart:io';

import '../utils.dart';

Future<void> main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final qrScannerStatements = {
    'moduleStatements': [
      "import 'package:ensemble_qr_scanner/qr_code_scanner.dart';",
      "GetIt.I.registerSingleton<EnsembleQRCodeScanner>(",
      "     EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));",
    ],
    'useStatements': [
      'static const useCamera = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_qr_scanner:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/qr_scanner''',
      'regex':
          r'#\s*ensemble_qr_scanner:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/qr_scanner',
    }
  ];

  final iOSPermissions = [
    {
      'key': 'cameraDescription',
      'value': 'NSCameraUsageDescription',
    },
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      qrScannerStatements['moduleStatements'],
      qrScannerStatements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Add the camera permission to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: [
        '<uses-permission android:name="android.permission.CAMERA" />'
      ]);
    }

    // Add the camera usage description to the iOS Info.plist file
    if (platforms.contains('ios')) {
      updateIOSPermissions(iOSPermissions, arguments);
    }

    print('QR Scanner module enabled successfully for ${platforms.join(', ')}! 🎉');
    print('Note: This is the lightweight module with only QR/Barcode scanning.');
    print('For camera/video features, use enable_camera.dart instead.');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
