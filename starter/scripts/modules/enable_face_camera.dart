import 'dart:io';

import '../utils.dart';

Future<void> main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final faceCameraStatements = {
    'moduleStatements': [
      "import 'package:ensemble_face_camera/ensemble_face_camera.dart';",
      "GetIt.I.registerSingleton<FaceCameraManager>(FaceCameraManagerImpl());",
    ],
    'useStatements': [
      'static const useFaceCamera = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_face_camera:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/face_camera''',
      'regex':
          r'#\s*ensemble_face_camera:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/face_camera',
    }
  ];

  final iOSPermissions = [
    {
      'key': 'cameraDescription',
      'value': 'NSCameraUsageDescription',
    },
    {
      'key': 'photoLibraryDescription',
      'value': 'NSPhotoLibraryUsageDescription',
    },
    {
      'key': 'microphoneDescription',
      'value': 'NSMicrophoneUsageDescription',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      faceCameraStatements['moduleStatements'],
      faceCameraStatements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Add the camera permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: [
        '<uses-permission android:name="android.permission.CAMERA" />'
      ]);
    }

    // Add the camera usage description to the iOS Info.plist file
    if (platforms.contains('ios')) {
      updateIOSPermissions(iOSPermissions, arguments);
    }

    // Add the face detection models to the web/index.html file
    if (platforms.contains('web')) {
      const webIndexHtml = '''
<!-- Face Detection Scripts -->
  <script src="assets/packages/ensemble_face_camera/web/face_api.js"></script>
  <script src="assets/packages/ensemble_face_camera/web/face_detection.js"></script>
<!-- Image worker Script -->
  <script src="assets/packages/ensemble_face_camera/web/image_worker.js"></script>
''';
      updateWebIndexHtml(webIndexHtml, '<!-- Face Detection -->');
    }

    print('Face Camera module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
