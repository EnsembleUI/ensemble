import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

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
      ref: main
      path: modules/connect''',
      'regex':
          r'#\s*ensemble_connect:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/connect',
    }
  ];

  try {
    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      ensembleModulesFilePath,
      statements['moduleStatements'],
      statements['useStatements'],
    );

    // Update the pubspec.yaml file
    updatePubspec(pubspecFilePath, pubspecDependencies);

    print(
        'Connect module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}