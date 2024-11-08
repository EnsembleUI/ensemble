import 'dart:io';

import '../utils.dart';

void main(List<String> arguments) async {
  List<String> platforms = getPlatforms(arguments);

  final statements = {
    'moduleStatements': [
      "import 'package:ensemble_network_info/network_info.dart';",
      'GetIt.I.registerSingleton<NetworkInfoManager>(NetworkInfoImpl());',
    ],
    'useStatements': [
      'static const useNetworkInfo = true;',
    ],
  };

  final pubspecDependencies = [
    {
      'statement': '''
ensemble_network_info:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await getEnsembleRef()}
      path: modules/ensemble_network_info''',
      'regex':
          r'#\s*ensemble_network_info:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/ensemble_network_info',
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

    print(
        'Network Info module enabled successfully for ${platforms.join(', ')}! 🎉');
    exit(0);
  } catch (e) {
    print('Starter Error: $e');
    exit(1);
  }
}
