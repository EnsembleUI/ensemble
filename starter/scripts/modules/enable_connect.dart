import 'dart:io';

import '../utils.dart';
import '../utils/firebase_utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);
  String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_connect/plaid_link/plaid_link_manager.dart';",
      "GetIt.I.registerSingleton<PlaidLinkManager>(PlaidLinkManagerImpl());",
    ],
    'useStatements': [
      'static const useConnect = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_connect:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/connect''',
      'regex':
          r'#\s*ensemble_connect:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/connect',
    }
  ];

  final iOSPermissions = [
    {
      'key': 'cameraDescription',
      'value': 'NSCameraUsageDescription',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    updatePubspec(pubspecDependencies);

    if (platforms.contains('android')) {
      addImplementationDependency(
          "implementation 'org.openjsse:openjsse:1.1.10'");
      addImplementationDependency(
          "implementation 'org.conscrypt:conscrypt-android:2.5.3'");
      updateBuildGradle(minifyEnabled: false, shrinkResources: false);
    }

    if (platforms.contains('ios')) {
      updateIOSPermissions(iOSPermissions, arguments);
    }

    // Add the <script> tag to index.html for web platform
    if (platforms.contains('web')) {
      updateHtmlFile(
        '</head>',
        '<script src="https://cdn.plaid.com/link/v2/stable/link-initialize.js"></script>',
        removalPattern:
            r'https://cdn\.plaid\.com/link/v2/stable/link-initialize\.js',
      );
    }

    print(
        'Connect module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}

void updateBuildGradle(
    {bool minifyEnabled = false, bool shrinkResources = false}) {
  final buildGradleFile = File('android/app/build.gradle');
  String content = buildGradleFile.readAsStringSync();

  if (!content.contains('minifyEnabled')) {
    content = content.replaceAllMapped(
        RegExp(r'buildTypes\s*{[^}]*release\s*{', multiLine: true),
        (match) =>
            "buildTypes {\n        release {\n            minifyEnabled $minifyEnabled");
  }

  if (!content.contains('shrinkResources')) {
    content = content.replaceAllMapped(
        RegExp(r'buildTypes\s*{[^}]*release\s*{', multiLine: true),
        (match) =>
            "buildTypes {\n        release {\n            shrinkResources $shrinkResources");
  }

  buildGradleFile.writeAsStringSync(content);
}
