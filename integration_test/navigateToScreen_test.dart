import 'package:ensemble/ensemble.dart';
import 'package:ensemble/widget/button.dart';
import 'package:flutter_test/flutter_test.dart';

import 'framework/test_helper.dart';

void main() {
  EnsembleConfig? config;
  setUpAll(() async {
    config = await TestHelper.setupApp(appName: 'navigateToScreen');
  });

  group('Navigation App Tests', () {
    testWidgets("Ensure inputs are passed properly to the next screen",
        (tester) async {
      await TestHelper.loadScreen(screenName: 'FirstScreen', config: config);
      await tester.pumpAndSettle();

      Finder firstScreenButton = find.byType(Button).first;
      await tester.tap(firstScreenButton);
      await tester.pumpAndSettle();

      Finder passedValueText = find.text('Value from first screen');
      expect(passedValueText, findsOneWidget);
    });

    testWidgets("Clear all screens and ensure the back button doesn't appear",
        (tester) async {
      await TestHelper.loadScreen(screenName: 'FirstScreen', config: config);
      await tester.pumpAndSettle();

      // Find and tap the "Navigate to new screen and pass some data" button
      Finder firstScreenButton = find.text('Navigate to new screen and pass some data');
      await tester.tap(firstScreenButton);
      await tester.pumpAndSettle();

      // Find and tap the "Go back to First Screen" button
      Finder backButton = find.text('Go back to First Screen');
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Check if the "Go back to First Screen" button is not in the widget tree anymore
      expect(backButton, findsNothing);
    });

    testWidgets('Test replaceCurrentScreen', (tester) async {
      await TestHelper.loadScreen(screenName: 'FirstScreen', config: config);
      await tester.pumpAndSettle();

      // Find the navigation button on the first screen
      final navigateButton = find.text('Navigate to new screen and replace the current screen');
      expect(navigateButton, findsOneWidget);

      // Tap the navigation button
      await tester.tap(navigateButton);
      await tester.pumpAndSettle();

      // Verify that the second screen is displayed
      expect(find.text('Second Screen'), findsOneWidget);

      // Find and tap the go back button
      final goBackButton = find.text('Go back to First Screen');
      expect(goBackButton, findsOneWidget);
      await tester.tap(goBackButton);
      await tester.pumpAndSettle();

      // Verify that the first screen is displayed again
      expect(find.text('First Screen'), findsOneWidget);

      // Verify that the second screen is not in the widget tree
      expect(find.text('Second Screen'), findsNothing);
    });
  });
}
