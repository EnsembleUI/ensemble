import 'dart:io';

import '../utils.dart';

Future<void> main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  final cameraStatements = {
    'moduleStatements': [
      "import 'package:ensemble_camera/qr_code_scanner.dart';",
      "GetIt.I.registerSingleton<EnsembleQRCodeScanner>(",
      "     EnsembleQRCodeScannerImpl.build(EnsembleQRCodeScannerController()));",
    ],
  };

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      cameraStatements['moduleStatements'],
      cameraStatements['useStatements'],
    );

    print('QR module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
