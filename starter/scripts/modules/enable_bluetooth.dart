import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_bluetooth/ensemble_bluetooth.dart';",
      'GetIt.I.registerSingleton<BluetoothManager>(BluetoothManagerImpl());',
    ],
    'useStatements': [
      'static const useBluetooth = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_bluetooth:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/ensemble_bluetooth''',
      'regex':
          r'#\s*ensemble_bluetooth:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/ensemble_bluetooth',
    }
  ];

  final androidPermissions = [
    // New Android 12 Bluetooth permissions
    '<uses-permission android:name="android.permission.BLUETOOTH_SCAN" android:usesPermissionFlags="neverForLocation" />',
    '<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />',
    // Legacy permissions for Android 11 or lower
    '<uses-permission android:name="android.permission.BLUETOOTH" android:maxSdkVersion="30" />',
    '<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" android:maxSdkVersion="30" />',
    // Tell Play Store app uses Bluetooth LE
    '<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />',
  ];

  final iOSPermissions = [
    {
      'key': 'bluetoothDescription',
      'value': 'NSBluetoothAlwaysUsageDescription',
    },
    {
      'key': 'bluetoothPeripheralDescription',
      'value': 'NSBluetoothPeripheralUsageDescription',
    }
  ];

  final iOSAdditionalSettings = [
    {
      'key': 'UIBackgroundModes',
      'value': ['bluetooth-central', 'bluetooth-peripheral'],
      'isArray': true,
    },
    {
      'key': 'NSBluetoothServices',
      'value': ['180A', '180F', '1812'],
      'isArray': true,
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecDependencies);

    // Add required permissions to AndroidManifest.xml
    if (platforms.contains('android')) {
      updateAndroidPermissions(permissions: androidPermissions);
    }

    // Add required permissions to Info.plist for iOS
    if (platforms.contains('ios')) {
      updateIOSPermissions(
        iOSPermissions,
        arguments,
        additionalSettings: iOSAdditionalSettings,
      );
    }

    print(
        'Bluetooth module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
