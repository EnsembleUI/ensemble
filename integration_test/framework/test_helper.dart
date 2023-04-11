import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/provider.dart';
import 'package:flutter/widgets.dart';
import 'package:integration_test/integration_test.dart';

class TestHelper {
  /// Setup the App once for every Test Group.
  /// If we run multiple tests
  /// by calling runApp() again, rootBundle.getString() will cache
  /// the result but no longer available for the next run, causing the
  /// subsequent tests to hang. For this reason, call this in your Test class's
  /// setupApp() once before running the tests.
  static Future<EnsembleConfig> setupApp({required String appName}) async {
    IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    WidgetsFlutterBinding.ensureInitialized();

    I18nProps i18nProps = I18nProps('en', 'en', false);
    i18nProps.path = 'ensemble/i18n';

    EnsembleConfig config = EnsembleConfig(
        definitionProvider: LocalDefinitionProvider(
            "ensemble/integration_tests/$appName/", "", i18nProps));
    return await config.updateAppBundle();
  }

  static loadScreen(
      {required String screenName, required EnsembleConfig? config}) {
    if (config == null) {
      throw Exception(
          'Config is required. Please run setupApp() per Test Class to initialize the EnsembleConfig once !');
    }
    runApp(EnsembleApp(
      key: UniqueKey(),
      ensembleConfig: config,
      screenPayload: ScreenPayload(screenName: screenName),
    ));
  }

  /// initialize an App and init a single screen for testing.
  /// This is a quick way to run a test, but it should be the only test
  /// in your test class.
  /// Considering using setupApp(), followed by loadScreen() for multiple
  /// test cases within a class.
  static Future<void> setupAppForSingleScreen(
      {required String appName, required String screenName}) async {
    EnsembleConfig config = await setupApp(appName: appName);
    loadScreen(screenName: screenName, config: config);
  }
}
