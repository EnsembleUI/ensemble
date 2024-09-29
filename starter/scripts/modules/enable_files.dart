import '../utils.dart';

void main() {
  const ensembleModulesFilePath = 'lib/generated/ensemble_modules.dart';
  const pubspecFilePath = 'pubspec.yaml';

  bool success = true;

  // Update the ensemble_modules.dart file
  try {
    String content = readFileContent(ensembleModulesFilePath);

    // Uncomment the FileManager import statement
    content = updateContent(
      content,
      r"\/\/\s*import\s+\'package:ensemble_file_manager\/file_manager\.dart\';",
      'import \'package:ensemble_file_manager/file_manager.dart\';',
    );

    // Set useFiles to true
    content = updateContent(
      content,
      r'static\s+const\s+useFiles\s*=\s*(true|false);',
      'static const useFiles = true;',
    );

    // Uncomment FileManagerImpl
    content = updateContent(
      content,
      r'\/\/\s*GetIt\.I\.registerSingleton<FileManager>\(FileManagerImpl\(\)\);',
      'GetIt.I.registerSingleton<FileManager>(FileManagerImpl());',
    );

    writeFileContent(ensembleModulesFilePath, content);
  } catch (e) {
    print(e);
    success = false;
  }

  // Update the pubspec.yaml file
  try {
    String pubspecContent = readFileContent(pubspecFilePath);

    pubspecContent = updateContent(
      pubspecContent,
      r'#\s*ensemble_file_manager:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/file_manager',
      'ensemble_file_manager:\n    git:\n      url: https://github.com/EnsembleUI/ensemble.git\n      ref: main\n      path: modules/file_manager',
    );

    writeFileContent(pubspecFilePath, pubspecContent);
  } catch (e) {
    print(e);
    success = false;
  }

  if (success) {
    print('Files module enabled successfully! 🎉');
  }
}
