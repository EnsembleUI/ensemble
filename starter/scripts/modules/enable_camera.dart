import '../utils.dart';

void main(List<String> arguments) {
  const ensembleModulesFilePath = 'lib/generated/ensemble_modules.dart';
  const pubspecFilePath = 'pubspec.yaml';
  const androidManifestFilePath = 'android/app/src/main/AndroidManifest.xml';
  const iosInfoPlistFilePath = 'ios/Runner/Info.plist';

  List<String> platforms = getPlatforms(arguments);

  bool success = true;

  // Update the ensemble_modules.dart file
  try {
    String content = readFileContent(ensembleModulesFilePath);

    // Uncomment the CameraManager import statement
    content = updateContent(
      content,
      r"\/\/\s*import\s+\'package:ensemble_camera\/camera_manager\.dart\';",
      'import \'package:ensemble_camera/camera_manager.dart\';',
    );

    // Set useCamera to true
    content = updateContent(
      content,
      r'static\s+const\s+useCamera\s*=\s*(true|false);',
      'static const useCamera = true;',
    );

    // Uncomment CameraManagerImpl
    content = updateContent(
      content,
      r'\/\/\s*GetIt\.I\.registerSingleton<CameraManager>\(CameraManagerImpl\(\)\);',
      'GetIt.I.registerSingleton<CameraManager>(CameraManagerImpl());',
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
      r'#\s*ensemble_camera:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/camera',
      'ensemble_camera:\n    git:\n      url: https://github.com/EnsembleUI/ensemble.git\n      ref: main\n      path: modules/camera',
    );

    writeFileContent(pubspecFilePath, pubspecContent);
  } catch (e) {
    print(e);
    success = false;
  }

  // Add the camera permission to the AndroidManifest.xml
  if (platforms.contains('android')) {
    try {
      addPermissionToAndroidManifest(
        androidManifestFilePath,
        '<!-- UPDATE for your Starter. These are default permissions -->',
        '<uses-permission android:name="android.permission.CAMERA" />',
      );
    } catch (e) {
      print('Error updating AndroidManifest.xml: $e');
      success = false;
    }
  }

  // Add the camera usage description to the iOS Info.plist file
  if (platforms.contains('ios')) {
    try {
      String cameraDescription = '';
      if (arguments.contains('--camera_description')) {
        cameraDescription =
            arguments[arguments.indexOf('--camera_description') + 1];
      }

      print(cameraDescription);
      if (cameraDescription.isNotEmpty) {
        addPermissionDescriptionToInfoPlist(
          iosInfoPlistFilePath,
          'NSCameraUsageDescription',
          cameraDescription,
        );
      }
    } catch (e) {
      print('Error updating Info.plist: $e');
      success = false;
    }
  }

  if (success) {
    print('Camera module enabled successfully for ${platforms.join(', ')}! 🎉');
  }
}
