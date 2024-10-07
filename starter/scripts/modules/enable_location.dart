import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) {
  List<String> platforms = getPlatforms(arguments);

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_location/location_module.dart';",
      "GetIt.I.registerSingleton<LocationModule>(LocationModuleImpl());",
    ],
    'useStatements': [
      'static const useLocation = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_location:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: main
      path: modules/location''',
      'regex':
          r'#\s*ensemble_location:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/location',
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
        'Location module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
