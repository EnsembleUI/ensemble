import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  bool success = true;

  // Define the file manager module statements
  final fileManagerStatements = {
    'importStatements': [
      {
        'statement':
            "import 'package:ensemble_file_manager/file_manager.dart';",
        'regex': toRegexPattern(
            "import 'package:ensemble_file_manager/file_manager.dart';"),
      }
    ],
    'registerStatements': [
      {
        'statement':
            'GetIt.I.registerSingleton<FileManager>(FileManagerImpl());',
        'regex': toRegexPattern(
            'GetIt.I.registerSingleton<FileManager>(FileManagerImpl());'),
      }
    ],
    'useStatements': [
      {
        'statement': 'static const useFiles = true;',
        'regex':
            toRegexPattern('static const useFiles = true;', isBoolean: true),
      }
    ],
    'pubspecDependencies': [
      {
        'statement': '''
ensemble_file_manager:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/file_manager
''',
        'regex':
            r'#\s*ensemble_file_manager:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/file_manager',
      }
    ],
  };

  // Define Android and iOS permissions for the file manager
  final androidPermissions = [
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />',
    '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />',
  ];

  final iOSPermissions = [
    {
      'paramKey': '--photo_library_description',
      'key': 'NSPhotoLibraryUsageDescription',
    },
    {
      'paramKey': '--music_description',
      'key': 'NSAppleMusicUsageDescription',
    }
  ];

  // Additional settings for Info.plist (arrays, booleans)
  final iOSAdditionalSettings = [
    {
      'key': 'UIBackgroundModes',
      'value': ['fetch', 'remote-notification'],
      'isArray': true,
    },
    {
      'key': 'UISupportsDocumentBrowser',
      'value': true,
      'isBoolean': true,
    },
    {
      'key': 'LSSupportsOpeningDocumentsInPlace',
      'value': true,
      'isBoolean': true,
    },
  ];

  // Update the ensemble_modules.dart file
  try {
    updateEnsembleModules(
        ensembleModulesFilePath,
        fileManagerStatements['importStatements']!,
        fileManagerStatements['registerStatements']!,
        fileManagerStatements['useStatements']!);
  } catch (e) {
    print(e);
    success = false;
  }

  // Update the pubspec.yaml file
  try {
    updatePubspec(
        pubspecFilePath, fileManagerStatements['pubspecDependencies']!);
  } catch (e) {
    print(e);
    success = false;
  }

  // Add the storage permissions to the AndroidManifest.xml
  if (platforms.contains('android')) {
    try {
      updateAndroidPermissions(androidManifestFilePath, androidPermissions);
    } catch (e) {
      print('Error updating AndroidManifest.xml: $e');
      success = false;
    }
  }

  // Add the required keys and descriptions to the Info.plist file for iOS
  if (platforms.contains('ios')) {
    try {
      updateIOSPermissions(
        iosInfoPlistFilePath,
        iOSPermissions,
        arguments,
        additionalSettings: iOSAdditionalSettings,
      );
    } catch (e) {
      print('Error updating Info.plist: $e');
      success = false;
    }
  }

  if (success) {
    print('Files module enabled successfully! 🎉');
  }
}
