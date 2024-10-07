import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_deeplink/deferred_link_manager.dart';",
      'GetIt.I.registerSingleton<DeferredLinkManager>(DeferredLinkManagerImpl());',
    ],
    'useStatements': [
      'static const useDeeplink = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_deeplink:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/deeplink''',
      'regex':
          r'#\s*ensemble_deeplink:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/deeplink',
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
        'Deeplink module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
