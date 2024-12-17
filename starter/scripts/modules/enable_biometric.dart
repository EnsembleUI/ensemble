import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);

  final androidPermissions = [
    '<uses-permission android:name="android.permission.USE_BIOMETRIC"/>',
  ];

  final iOSPermissions = [
    {
      'key': 'faceIdDescription',
      'value': 'NSFaceIDUsageDescription',
    }
  ];

  try {
    // Add the biometric permission to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: androidPermissions);

      // Update MainActivity to extend FlutterFragmentActivity
      final mainActivityUpdates = {
        'kotlin': [
          {
            'pattern':
                r'import\s+io\.flutter\.embedding\.android\.FlutterActivity',
            'replacement':
                'import io.flutter.embedding.android.FlutterFragmentActivity'
          },
          {
            'pattern': r'class\s+MainActivity\s*:\s*FlutterActivity\(\)',
            'replacement': 'class MainActivity: FlutterFragmentActivity()'
          }
        ],
        'java': [
          {
            'pattern':
                r'import\s+io\.flutter\.embedding\.android\.FlutterActivity;',
            'replacement':
                'import io.flutter.embedding.android.FlutterFragmentActivity;'
          },
          {
            'pattern':
                r'public\s+class\s+MainActivity\s+extends\s+FlutterActivity',
            'replacement':
                'public class MainActivity extends FlutterFragmentActivity'
          }
        ]
      };

      updateMainActivity(mainActivityUpdates);
    }

    // Add Face ID usage description to Info.plist for iOS
    if (platforms.contains('ios')) {
      updateIOSPermissions(iOSPermissions, arguments);
    }

    print('Biometric enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
