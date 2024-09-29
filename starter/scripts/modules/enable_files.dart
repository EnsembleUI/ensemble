import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

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

  // Add the storage permissions to the AndroidManifest.xml
  if (platforms.contains('android')) {
    try {
      addPermissionToAndroidManifest(
        androidManifestFilePath,
        '<!-- UPDATE for your Starter. These are default permissions -->',
        '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />',
      );

      addPermissionToAndroidManifest(
        androidManifestFilePath,
        '<!-- UPDATE for your Starter. These are default permissions -->',
        '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />',
      );
    } catch (e) {
      print('Error updating AndroidManifest.xml: $e');
      success = false;
    }
  }

  // Add the required keys and descriptions to the Info.plist file
  if (platforms.contains('ios')) {
    try {
      String photoLibraryDescription = '';
      String musicDescription = '';

      for (int i = 0; i < arguments.length; i++) {
        if (arguments[i] == '--photo_library_description' &&
            i + 1 < arguments.length) {
          photoLibraryDescription = arguments[i + 1];
        }
        if (arguments[i] == '--music_description' && i + 1 < arguments.length) {
          musicDescription = arguments[i + 1];
        }
      }

      addPermissionDescriptionToInfoPlist(
        iosInfoPlistFilePath,
        'UIBackgroundModes',
        ['fetch', 'remote-notification'],
        isArray: true,
      );

      if (musicDescription.isNotEmpty) {
        addPermissionDescriptionToInfoPlist(
          iosInfoPlistFilePath,
          'NSAppleMusicUsageDescription',
          musicDescription,
        );
      }

      addPermissionDescriptionToInfoPlist(
        iosInfoPlistFilePath,
        'UISupportsDocumentBrowser',
        true,
        isBoolean: true,
      );

      addPermissionDescriptionToInfoPlist(
        iosInfoPlistFilePath,
        'LSSupportsOpeningDocumentsInPlace',
        true,
        isBoolean: true,
      );

      if (photoLibraryDescription.isNotEmpty) {
        addPermissionDescriptionToInfoPlist(
          iosInfoPlistFilePath,
          'NSPhotoLibraryUsageDescription',
          photoLibraryDescription,
        );
      }
    } catch (e) {
      print('Error updating Info.plist: $e');
      success = false;
    }
  }

  if (success) {
    print('Files module enabled successfully! 🎉');
  }
}
