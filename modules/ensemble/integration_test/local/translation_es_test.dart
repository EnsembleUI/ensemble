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

      expect(find.text("Hola Peter"), findsOneWidget);

      await tester.tap(find.text("Show Toast"));
      await tester.pumpAndSettle();
      expect(find.text("Hola Hola Peter"), findsOneWidget);
    });
  });
}
