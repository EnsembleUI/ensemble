import 'dart:io';

import '../constants.dart';
import '../utils.dart';
import '../utils/firebase_utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);

  // Extract client ID values from the arguments
  String iOSClientId = getArgumentValue(arguments, 'googleIOSClientId') ?? '';
  String androidClientId =
      getArgumentValue(arguments, 'googleAndroidClientId') ?? '';
  String webClientId = getArgumentValue(arguments, 'googleWebClientId') ?? '';
  String serverClientId =
      getArgumentValue(arguments, 'googleServerClientId') ?? '';

  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_auth/auth_module.dart';",
      'GetIt.I.registerSingleton<AuthModule>(AuthModuleImpl());',
    ],
    'useStatements': [
      'static const useAuth = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_auth:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/auth''',
      'regex':
          r'#\s*ensemble_auth:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/auth',
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

    // Update the auth module configuration in ensemble-config.yaml
    updateAuthConfig(iOSClientId, androidClientId, webClientId, serverClientId);
    updateFirebaseConfig(platforms, arguments);
    if (platforms.contains('android')) {
      createProguardRules(authProguardRules);
      addClasspathDependency(
          "classpath 'com.google.gms:google-services:4.3.15'");
      addPluginDependency("apply plugin: 'com.google.gms.google-services'");
      addSettingsPluginDependency(
          'id "com.google.gms.google-services" version "4.3.15" apply false');
      addImplementationDependency(
          "implementation platform('com.google.firebase:firebase-bom:32.7.0')");
    }

    // Update the iOS Info.plist
    if (platforms.contains('ios') && iOSClientId.isNotEmpty) {
      updateInfoPlist(iOSClientId);
    }

    if (platforms.contains('web') && webClientId.isNotEmpty) {
      updateHtmlFile('</head>',
          '<meta name="google-signin-client_id" content="$webClientId">',
          removalPattern:
              r'<meta name="google-signin-client_id" content=".*">');
    }

    print(
        'Auth module enabled and configuration updated successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}

void updateAuthConfig(String iOSClientId, String androidClientId,
    String webClientId, String serverClientId) {
  try {
    final file = File(ensembleConfigFilePath);
    if (!file.existsSync()) {
      throw Exception('Config file not found.');
    }

    String content = file.readAsStringSync();

    // Define a map of client IDs and their corresponding config keys
    final clientIds = {
      'iOSClientId': iOSClientId,
      'androidClientId': androidClientId,
      'webClientId': webClientId,
      'serverClientId': serverClientId,
    };

    // Replace each client ID if it's not empty
    clientIds.forEach((key, value) {
      if (value.isNotEmpty) {
        content = content.replaceAllMapped(
          RegExp('$key:\\s*.*', multiLine: true),
          (match) => '$key: $value',
        );
      } else {
        content = content.replaceAllMapped(
          RegExp('$key:\\s*.*', multiLine: true),
          (match) => '$key:',
        );
      }
    });

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception(
        'Failed to update auth configuration in ensemble-config.yaml: $e');
  }
}

void updateInfoPlist(String iOSClientId) {
  try {
    final file = File(iosInfoPlistFilePath);
    if (!file.existsSync()) {
      throw Exception('Info.plist file not found.');
    }

    String content = file.readAsStringSync();

    final clientIdParts = iOSClientId.split('-');
    iOSClientId = 'com.googleusercontent.apps.${clientIdParts[0]}';

    // Replace the current iOS client ID in the Info.plist file
    content = content.replaceAllMapped(
      RegExp(
          r'<string>com\.googleusercontent\.apps\.\d+-[a-zA-Z0-9]+</string>'),
      (match) => '<string>$iOSClientId</string>',
    );

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception('Failed to update Info.plist: $e');
  }
}

void createProguardRules(String rules) {
  try {
    final file = File(proguardRulesFilePath);
    if (!file.existsSync()) {
      file.createSync(recursive: true);
    }

    final content = file.readAsStringSync();

    if (!content.contains(rules) && rules.isNotEmpty) {
      file.writeAsStringSync('$content\n$rules');
      updateBuildGradleProguardFiles();
    }
  } catch (e) {
    throw Exception(
        '❌ Starter Error: Failed to create proguard-rules.pro file: $e');
  }
}

void updateBuildGradleProguardFiles() {
  try {
    final file = File(androidAppBuildGradleFilePath);
    if (!file.existsSync()) {
      throw Exception('build.gradle file not found.');
    }

    String content = file.readAsStringSync();

    // Update the proguardFiles in the build.gradle file
    if (!content.contains('proguardFiles')) {
      content = content.replaceAllMapped(
          RegExp(r'buildTypes\s*{[^}]*release\s*{', multiLine: true),
          (match) =>
              "buildTypes {\n        release {\n            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'");
    }

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception('❌ Starter Error: Failed to update build.gradle: $e');
  }
}
