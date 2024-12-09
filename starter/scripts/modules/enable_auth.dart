import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);

  // Extract client ID values from the arguments
  String iOSClientId = getArgumentValue(arguments, 'ios_client_id',
          required: platforms.contains('ios')) ??
      '';
  String androidClientId = getArgumentValue(arguments, 'android_client_id',
          required: platforms.contains('android')) ??
      '';
  String webClientId = getArgumentValue(arguments, 'web_client_id',
          required: platforms.contains('web')) ??
      '';
  String serverClientId =
      getArgumentValue(arguments, 'server_client_id', required: true) ?? '';

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

    // Update the iOS Info.plist with the ios_client_id
    if (platforms.contains('ios')) {
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

    // Replace the current iOS client ID in the Info.plist file
    content = content.replaceAllMapped(
      RegExp(
          r'<string>com\.googleusercontent\.apps\.\d+-[a-zA-Z0-9]+</string>'),
      (match) => '<string>$iOSClientId</string>',
    );

    file.writeAsStringSync(content);
    print('Updated Info.plist with iOS client ID: $iOSClientId');
  } catch (e) {
    throw Exception('Failed to update Info.plist: $e');
  }
}
