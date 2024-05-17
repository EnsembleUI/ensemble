import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/provider.dart';
import 'package:ensemble/widget/input/dropdown.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mockito/mockito.dart';
import 'package:collection/collection.dart';

class TestHelper {
  /// Setup the App once for every Test Group.
  /// If we run multiple tests
  /// by calling runApp() again, rootBundle.getString() will cache
  /// the result but no longer available for the next run, causing the
  /// subsequent tests to hang. For this reason, call this in your Test class's
  /// setupApp() once before running the tests.
  static Future<EnsembleConfig> setupApp(
      {required String appName, String? forcedLocale}) async {
    I18nProps i18nProps =
        I18nProps('en', 'en', false, forcedLocale: forcedLocale);
    i18nProps.path = 'integration_test/local/$appName/i18n';

    EnsembleConfig config = EnsembleConfig(
        definitionProvider: LocalDefinitionProvider(
            "integration_test/local/$appName/", "", i18nProps));
    return config.updateAppBundle();
  }

  // load a screen based on the config returned from setupApp
  static loadScreen(
      WidgetTester tester, String screenName, EnsembleConfig config) async {
    await tester.pumpWidget(EnsembleApp(
      ensembleConfig: config,
      screenPayload: ScreenPayload(screenId: screenName),
    ));
    await tester.pumpAndSettle();
  }

  /// initialize an App and init a single screen for testing.
  /// This is a quick way to run a test, but it should be the only test
  /// in your test class.
  /// Considering using setupApp(), followed by loadScreen() for multiple
  /// test cases within a class.
  static loadAppAndScreen(WidgetTester tester,
      {required String appName, required String screenName}) async {
    EnsembleConfig config = await setupApp(appName: appName);
    await loadScreen(tester, screenName, config);
  }

  /// remove focus if any widget currently has focus
  static Future<void> removeFocus(WidgetTester tester) async {
    FocusNode blankNode = FocusNode();
    tester.binding.focusManager.rootScope.requestFocus(blankNode);
    await tester.pump();
  }

  static Finder? findFormWidgetByLabel<W extends Widget>(
      WidgetTester tester, String label) {
    // first try to find the form widget with label on top
    Finder formWidgetFinder = find.byWidgetPredicate((widget) {
      if (widget is W) {
        return find
            .descendant(
              of: find.byWidget(widget),
              matching: find.text(label),
            )
            .evaluate()
            .isNotEmpty;
      }
      return false;
    });
    if (formWidgetFinder.evaluate().isNotEmpty) {
      return formWidgetFinder;
    }
    // then fallback to find form widget with side-by-side label
    else {
      return _findFormWidgetBySideBySideLabel<W>(tester, label);
    }
    return null;
  }

  /// Side-by-side form widget's structure is more complex:
  /// Form:
  ///   Column:
  ///     Row:
  ///       Expanded:
  ///         Text:
  ///       Expanded:
  ///         <FormWidget>
  /// TODO: add support for labelPosition=top
  static Finder? _findFormWidgetBySideBySideLabel<W extends Widget>(
      WidgetTester tester, String formLabel) {
    Finder rowFinder = find.byWidgetPredicate((widget) {
      if (widget is Row) {
        final Expanded? labelExpanded = widget.children.firstWhereOrNull(
            (child) =>
                child is Expanded &&
                child.child is Text &&
                (child.child as Text).data == formLabel) as Expanded?;
        final Expanded? widgetExpanded = widget.children.firstWhereOrNull(
                (child) => child is Expanded && (child.child.runtimeType == W))
            as Expanded?;

        if (labelExpanded != null && widgetExpanded != null) {
          Element rowElement = find.byWidget(widget).evaluate().first;
          if (rowElement.findAncestorWidgetOfExactType<Form>() != null) {
            return true;
          }
        }
      }
      return false;
    });

    // return the actual finder that matches widgetType
    if (rowFinder.evaluate().isNotEmpty) {
      Finder found = find.descendant(
        of: rowFinder,
        matching: find.byType(W),
      );
      if (found.evaluate().isNotEmpty) {
        return found;
      }
    }
    return null;
  }
}

// DotEnv don't have access to the .env file so it'll fail in test
class MockDotEnv extends Mock implements DotEnv {}
