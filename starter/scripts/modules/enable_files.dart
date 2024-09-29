import 'dart:io';

void main() {
  // Paths to the files
  const ensembleModulesFilePath = 'lib/generated/ensemble_modules.dart';
  const pubspecFilePath = 'pubspec.yaml';

  bool success = true;

  // Update the ensemble_modules.dart file
  try {
    File ensembleModulesFile = File(ensembleModulesFilePath);
    if (ensembleModulesFile.existsSync()) {
      // Read file content
      String content = ensembleModulesFile.readAsStringSync();

      // Set useFiles to true
      content = content.replaceAllMapped(
        RegExp(r'static\s+const\s+useFiles\s*=\s*(true|false);'),
        (match) => 'static const useFiles = true;',
      );

      // Uncomment the FileManager import statement
      content = content.replaceAllMapped(
        RegExp(
            r"\/\/\s*import\s+\'package:ensemble_file_manager\/file_manager\.dart\';"),
        (match) =>
            'import \'package:ensemble_file_manager/file_manager.dart\';',
      );

      // Uncomment the lines related to FileManagerImpl in the useFiles section
      content = content.replaceAllMapped(
        RegExp(
            r'\/\/\s*GetIt\.I\.registerSingleton<FileManager>\(FileManagerImpl\(\)\);'),
        (match) => 'GetIt.I.registerSingleton<FileManager>(FileManagerImpl());',
      );

      // Write the updated content back to the file
      ensembleModulesFile.writeAsStringSync(content);
    } else {
      print('Error: ensemble_modules.dart file not found.');
      success = false;
    }
  } catch (e) {
    print('Error updating ensemble_modules.dart: $e');
    success = false;
  }

  // Update the pubspec.yaml file
  try {
    File pubspecFile = File(pubspecFilePath);
    if (pubspecFile.existsSync()) {
      // Read file content
      String pubspecContent = pubspecFile.readAsStringSync();

      // Correctly format and uncomment the file_manager module in pubspec.yaml
      pubspecContent = pubspecContent.replaceAllMapped(
        RegExp(
            r'#\s*ensemble_file_manager:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/file_manager'),
        (match) =>
            'ensemble_file_manager:\n    git:\n      url: https://github.com/EnsembleUI/ensemble.git\n      ref: main\n      path: modules/file_manager',
      );

      // Write the updated content back to the file
      pubspecFile.writeAsStringSync(pubspecContent);
    } else {
      print('Error: pubspec.yaml file not found.');
      success = false;
    }
  } catch (e) {
    print('Error updating pubspec.yaml: $e');
    success = false;
  }

  if (success) {
    print(
        'Files module enabled successfully in both ensemble_modules.dart and pubspec.yaml.');
  }
}
