import 'package:ensemble/ensemble.dart';
import 'package:ensemble/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../framework/test_helper.dart';

void main() {
  late EnsembleConfig config;
  setUpAll(() async {
    config = await TestHelper.setupApp(appName: 'dialog');
  });

  group('Testing Toast', () {
    testWidgets("works in Action and JS", (tester) async {
      await TestHelper.loadScreen(tester, 'Toast', config);

      // toast by Action
      await tester.tap(find.descendant(
          of: find.byType(Button), matching: find.text('Show Toast Action')));
      await tester.pumpAndSettle();
      expect(find.text('success by Action'), findsOneWidget);
      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();
      expect(find.text('success by Action'), findsNothing);

      // toast by JS
      await tester.tap(find.descendant(
          of: find.byType(Button), matching: find.text('Show Toast JS')));
      await tester.pumpAndSettle();
      expect(find.text('success by JS'), findsOneWidget);
      await tester.tap(find.byType(CircleAvatar));
      await tester.pumpAndSettle();
      expect(find.text('success by JS'), findsNothing);

      // use body widget
      await tester.tap(find.descendant(
          of: find.byType(Button), matching: find.text('Show Toast Widget')));
      await tester.pumpAndSettle();
      expect(find.text('success with body widget'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2)); // auto dismiss
      expect(find.text('success with body widget'), findsNothing);

      // use body custom widget
      await tester.tap(find.descendant(
          of: find.byType(Button),
          matching: find.text('Show Toast with custom widget')));
      await tester.pumpAndSettle();
      expect(find.text('custom body'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2)); // auto dismiss
      expect(find.text('custom body'), findsNothing);

      // use JS with custom widget with inputs
      await tester.tap(find.descendant(
          of: find.byType(Button),
          matching: find.text('Custom Widget with inputs')));
      await tester.pumpAndSettle();
      expect(find.text('Hello Peter Parker'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 2)); // auto dismiss
      expect(find.text('Hello Peter Parker'), findsNothing);
    });
  });
}
