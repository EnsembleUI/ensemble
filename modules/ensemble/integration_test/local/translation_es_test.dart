import 'dart:ui';

import 'package:ensemble/ensemble.dart';
import 'package:flutter_test/flutter_test.dart';

import '../framework/test_helper.dart';

void main() {
  group('Forcing Spanish locale', () {
    testWidgets("forcing Spanish locale should work", (tester) async {
      EnsembleConfig config = await TestHelper.setupApp(
          appName: 'translation', forcedLocale: Locale('es'));
      await TestHelper.loadScreen(tester, 'Basic', config);

      // test localized date/time/currency
      expect(find.text("20 jun 2024"), findsOneWidget);
      expect(find.text("14:02"), findsOneWidget);

      // some locales add special "NBSP" character between tokens that should not be wrapped (such as PM or euro currency),
      // so we need to account for the string match
      const NBSP = " ";

      // currency output uses "NBSP" instead of the space, so account for that.
      String expectedCurrency = "100,12${NBSP}€";
      expect(find.text(expectedCurrency), findsOneWidget);

      // watch out for non-breaking space between P and M
      String expectedDateStr = "jun 20 at 2:02p.${NBSP}m.";
      expect(find.text(expectedDateStr), findsOneWidget);

      // test using Date objects
      expect(find.text("14/3/2022"), findsOneWidget);
      expect(find.text("16:07:20"), findsOneWidget);
      expect(find.text("14/3/2022, 16:07:20"), findsOneWidget);

      // test translations
      expect(find.text("Hola Peter"), findsOneWidget);

      await tester.tap(find.text("Show Toast"));
      await tester.pumpAndSettle();
      expect(find.text("Hola Hola Peter"), findsOneWidget);
    });
  });
}
