import 'dart:io';

void main() {
  const ensembleModulesFilePath = 'lib/generated/ensemble_modules.dart';
  const pubspecFilePath = 'pubspec.yaml';

  bool success = true;

  // Update the ensemble_modules.dart file
  try {
    File ensembleModulesFile = File(ensembleModulesFilePath);
    if (ensembleModulesFile.existsSync()) {
      String content = ensembleModulesFile.readAsStringSync();

      content = content.replaceAllMapped(
        RegExp(
            r"\/\/\s*import\s+\'package:ensemble_camera\/camera_manager\.dart\';"),
        (match) => 'import \'package:ensemble_camera/camera_manager.dart\';',
      );

      content = content.replaceAllMapped(
        RegExp(r'static\s+const\s+useCamera\s*=\s*(true|false);'),
        (match) => 'static const useCamera = true;',
      );

      content = content.replaceAllMapped(
        RegExp(
            r'\/\/\s*GetIt\.I\.registerSingleton<CameraManager>\(CameraManagerImpl\(\)\);'),
        (match) =>
            'GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());',
      );

      ensembleModulesFile.writeAsStringSync(content);
    }
  } catch (e) {
    print('Error updating ensemble_modules.dart: $e');
    success = false;
  }

  // Update the pubspec.yaml file
  try {
    File pubspecFile = File(pubspecFilePath);
    if (pubspecFile.existsSync()) {
      String pubspecContent = pubspecFile.readAsStringSync();

      pubspecContent = pubspecContent.replaceAllMapped(
        RegExp(
            r'#\s*ensemble_camera:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/camera'),
        (match) =>
            'ensemble_camera:\n    git:\n      url: https://github.com/EnsembleUI/ensemble.git\n      ref: main\n      path: modules/camera',
      );

      pubspecFile.writeAsStringSync(pubspecContent);
    }
  } catch (e) {
    print('Error updating pubspec.yaml: $e');
    success = false;
  }

  if (success) {
    print('Camera module enabled successfully!');
  }
}
