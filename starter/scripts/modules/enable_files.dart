import 'dart:io';
import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  // Get permissions from arguments, default to all permissions
  List<String> androidPermissions = getPermissionsFromArguments(arguments);

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

  // Default Android permissions (all permissions)
  final defaultAndroidPermissions = [
    // For Android 9 (API 28) and below
    '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />',
    '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />',
    // For Android 13 (API 33) and above
    '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
    '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>',
    '<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>'
  ];

  // Use provided permissions or default to all
  final permissionsToAdd = androidPermissions.isNotEmpty
      ? androidPermissions
      : defaultAndroidPermissions;

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
      updateAndroidPermissions(permissions: permissionsToAdd);
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

// Helper function to extract permissions from arguments
List<String> getPermissionsFromArguments(List<String> arguments) {
  String? permissionsArg = getArgumentValue(arguments, 'permissions');

  if (permissionsArg == null) {
    return []; // Will default to all permissions
  }

  if (permissionsArg == 'none') {
    return [];
  } else if (permissionsArg == 'all') {
    return [
      '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />',
      '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />',
      '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>',
      '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>',
      '<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>'
    ];
  } else {
    // Parse individual permissions
    List<String> permissions = [];
    List<String> permissionList = permissionsArg.split(',');
    for (String permission in permissionList) {
      permission = permission.trim();
      switch (permission) {
        case 'read_external':
          permissions.add(
              '<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />');
          break;
        case 'write_external':
          permissions.add(
              '<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />');
          break;
        case 'read_media_images':
          permissions.add(
              '<uses-permission android:name="android.permission.READ_MEDIA_IMAGES"/>');
          break;
        case 'read_media_video':
          permissions.add(
              '<uses-permission android:name="android.permission.READ_MEDIA_VIDEO"/>');
          break;
        case 'read_media_audio':
          permissions.add(
              '<uses-permission android:name="android.permission.READ_MEDIA_AUDIO"/>');
          break;
      }
    }
    return permissions;
  }
}
