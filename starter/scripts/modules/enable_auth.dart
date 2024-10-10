import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

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
      ref: main
      path: modules/auth''',
      'regex':
          r'#\s*ensemble_auth:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/auth',
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

    print('Auth module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
