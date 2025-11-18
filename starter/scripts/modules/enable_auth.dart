import 'dart:io';

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

  String iosAppId = getArgumentValue(arguments, 'ios_appId',
          required: platforms.contains('ios')) ??
      '';

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
      addClasspathDependency(
          "classpath 'com.google.gms:google-services:4.3.15'");
      addPluginDependency("id 'com.google.gms.google-services'");
      addSettingsPluginDependency(
          'id "com.google.gms.google-services" version "4.3.15" apply false');
      addImplementationDependency(
          "implementation platform('com.google.firebase:firebase-bom:32.7.0')");
    }

    // Update the iOS Info.plist
    if (platforms.contains('ios') &&
        iOSClientId.isNotEmpty &&
        iosAppId.isNotEmpty) {
      updateInfoPlist(iOSClientId, iosAppId);
    }

    // Update the iOS entitlements file for Apple Sign In
    if (platforms.contains('ios') && iOSClientId.isNotEmpty) {
      updateEntitlements();
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
          (match) => '',
        );
      }
    });

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception(
        'Failed to update auth configuration in ensemble-config.yaml: $e');
  }
}

/// Extracts REVERSED_CLIENT_ID from GoogleService-Info.plist
String? getReversedClientIdFromGoogleServiceInfo() {
  // Try common locations for GoogleService-Info.plist
  final possiblePaths = [
    'ios/Runner/GoogleService-Info.plist',
    'ios/GoogleService-Info.plist',
  ];

  for (final path in possiblePaths) {
    final file = File(path);
    if (file.existsSync()) {
      try {
        final content = file.readAsStringSync();
        // Extract REVERSED_CLIENT_ID using regex
        final reversedClientIdPattern = RegExp(
            r'<key>\s*REVERSED_CLIENT_ID\s*</key>\s*<string>\s*([^<]+)\s*</string>',
            multiLine: true);
        final match = reversedClientIdPattern.firstMatch(content);
        if (match != null && match.groupCount >= 1) {
          return match.group(1)?.trim();
        }
      } catch (e) {
        // Continue to next path if this one fails
        continue;
      }
    }
  }
  return null;
}

void updateInfoPlist(String iOSClientId, String appId) {
  try {
    final file = File(iosInfoPlistFilePath);
    if (!file.existsSync()) {
      throw Exception('Info.plist file not found.');
    }

    String content = file.readAsStringSync();

    String reversedClientId;
    if (iOSClientId.contains(':')) {
      final reversedClientIdFromPlist =
          getReversedClientIdFromGoogleServiceInfo();
      if (reversedClientIdFromPlist != null &&
          reversedClientIdFromPlist.isNotEmpty) {
        reversedClientId = reversedClientIdFromPlist;
      } else {
        throw Exception(
            'The googleIOSClientId parameter appears to be a GOOGLE_APP_ID (contains colons: "$iOSClientId"). '
            'Please provide the CLIENT_ID from GoogleService-Info.plist instead (format: XXXXX-XXXXX.apps.googleusercontent.com). '
            'Alternatively, ensure GoogleService-Info.plist exists in ios/Runner/ or ios/ directory.');
      }
    } else {
      // It's a CLIENT_ID, so we need to reverse it
      final cleanedClientId =
          iOSClientId.replaceAll('.apps.googleusercontent.com', '');
      reversedClientId = 'com.googleusercontent.apps.$cleanedClientId';
    }

    // Replace colons and spaces with hyphens for the app ID to create a valid URL scheme
    final iosAppId = appId.replaceAll(':', '-').replaceAll(' ', '');

    // Pattern to match any URL scheme starting with com.googleusercontent.apps
    // This handles both valid formats and invalid formats with colons
    // More flexible pattern to handle whitespace variations (tabs, spaces)
    final urlSchemePattern = RegExp(
        r'<string>\s*com\.googleusercontent\.apps\.[^<]*</string>',
        multiLine: true);

    // Pattern to match any URL scheme starting with app- (for GOOGLE_APP_ID format)
    final appSchemePattern =
        RegExp(r'<string>\s*app-[^<]*</string>', multiLine: true);

    // Replace ALL occurrences of the reversed client ID scheme (handles both valid and invalid formats)
    // This includes malformed ones like com.googleusercontent.apps.1:885327415331:ios:...
    content = content.replaceAllMapped(
      urlSchemePattern,
      (match) => '<string>$reversedClientId</string>',
    );

    // Additional cleanup: Specifically target malformed patterns with colons
    // This pattern matches: com.googleusercontent.apps.DIGITS:... (GOOGLE_APP_ID format incorrectly prefixed)
    final malformedPattern = RegExp(
        r'<string>\s*com\.googleusercontent\.apps\.\d+:\d+:[^:]+:[^<]*</string>',
        multiLine: true);
    content = content.replaceAllMapped(
      malformedPattern,
      (match) => '<string>$reversedClientId</string>',
    );

    // Replace or add the app- scheme based on GOOGLE_APP_ID
    if (appSchemePattern.hasMatch(content)) {
      // Replace existing app- scheme
      content = content.replaceAllMapped(
        appSchemePattern,
        (match) => '<string>app-$iosAppId</string>',
      );
    } else {
      // Add new app- scheme if it doesn't exist
      // Find the CFBundleURLSchemes array and add the app- scheme
      final urlSchemesArrayPattern = RegExp(
          r'(<key>CFBundleURLSchemes</key>\s*<array>\s*<string>com\.googleusercontent\.apps\.[^<]*</string>)',
          multiLine: true);
      if (urlSchemesArrayPattern.hasMatch(content)) {
        content = content.replaceAllMapped(
          urlSchemesArrayPattern,
          (match) => '${match.group(1)}\n    			<string>app-$iosAppId</string>',
        );
      }
    }

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception('Failed to update Info.plist: $e');
  }
}

void updateEntitlements() {
  try {
    final file = File(runnerEntitlementsPath);
    if (!file.existsSync()) {
      throw Exception('Runner.entitlements file not found.');
    }

    String content = file.readAsStringSync();

    // Uncomment the Apple Sign In lines
    content = content.replaceAll(
      '	<!-- <key>com.apple.developer.applesignin</key> -->',
      '	<key>com.apple.developer.applesignin</key>',
    );
    content = content.replaceAll(
      '	<!-- <array>',
      '	<array>',
    );
    content = content.replaceAll(
      '		<string>Default</string>',
      '		<string>Default</string>',
    );
    content = content.replaceAll(
      '	</array> -->',
      '	</array>',
    );

    file.writeAsStringSync(content);
  } catch (e) {
    throw Exception('Failed to update Runner.entitlements: $e');
  }
}
