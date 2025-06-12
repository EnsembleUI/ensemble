import '../utils.dart';

void main(List<String> arguments) async {
  try {
    // Parse and validate arguments
    String? ensembleVersion = getArgumentValue(arguments, 'ensemble_version');
    String adobeAnalyticsAppId =
        getArgumentValue(arguments, 'adobeAnalyticsAppId', required: true) ??
            '';

    final statements = {
      'moduleStatements': [
        "import 'package:ensemble_adobe_analytics/adobe_analytics.dart';",
        'GetIt.I.registerSingleton<AdobeAnalyticsModule>(AdobeAnalyticsImpl());',
      ],
      'useStatements': [
        "static const useAdobeAnalytics = true;",
      ],
    };

    // Update the ensemble_modules.dart file
    updateEnsembleModules(
      statements['moduleStatements'],
      statements['useStatements'],
    );

    String modulesContent = readFileContent(ensembleModulesFilePath);
    modulesContent = modulesContent.replaceAll(
        'GetIt.I.registerSingleton<AdobeAnalyticsModule>(AdobeAnalyticsImpl());',
        'GetIt.I.registerSingleton<AdobeAnalyticsModule>(AdobeAnalyticsImpl(appId: "$adobeAnalyticsAppId"));');

    writeFileContent(ensembleModulesFilePath, modulesContent);

    // Update pubspec.yaml
    final pubspecDependencies = [
      {
        'statement': '''
ensemble_adobe_analytics:
    git:
      url: https://github.com/EnsembleUI/ensemble.git
      ref: ${await packageVersion(version: ensembleVersion)}
      path: modules/adobe_analytics''',
        'regex':
            r'#\s*ensemble_adobe_analytics:\s*\n\s*#\s*git:\s*\n\s*#\s*url:\s*https:\/\/github\.com\/EnsembleUI\/ensemble\.git\s*\n\s*#\s*ref:\s*main\s*\n\s*#\s*path:\s*modules\/adobe_analytics',
      },
    ];

    updatePubspec(pubspecDependencies);
  } catch (e) {
    print('Flutter: ❌ Failed to enable Adobe Analytics: $e');
  }
}
