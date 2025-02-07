import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final fileManagerStatements = {
    'moduleStatements': [
      "import 'package:ensemble_file_manager/file_manager.dart';",
      "GetIt.I.registerSingleton<FileManager>(FileManagerImpl());"
    ],
    'useStatements': ["static const useFiles = true;"],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_file_manager:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/file_manager''',
      'regex':
          r'#\s*ensemble_file_manager:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/file_manager',
    }
  ];

  final androidPermissions = [
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />',
    '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />',
  ];

  final iOSPermissions = [
    {
      'key': 'photoLibraryDescription',
      'value': 'NSPhotoLibraryUsageDescription',
    },
    {
      'key': 'musicDescription',
      'value': 'NSAppleMusicUsageDescription',
    }
  ];

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

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      fileManagerStatements['moduleStatements'],
      fileManagerStatements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Add the storage permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: androidPermissions);
    }

    // Add the required keys and descriptions to the Info.plist file for iOS
    if (platforms.contains('ios')) {
      updateIOSPermissions(
        iOSPermissions,
        arguments,
        additionalSettings: iOSAdditionalSettings,
      );
    }

    // Success message
    print(
        'File manager module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
