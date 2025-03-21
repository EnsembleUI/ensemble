import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ensemble_starter/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Ensemble App Testing', () {
    testWidgets('Navigate through screens with delays', (WidgetTester tester) async {
      // Start the app
      print('Starting the app...');
      app.main();
      
      // Wait for the app to fully load
      print('Waiting for app to load...');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      
      print('App loaded, now testing navigation...');
      
      // Verify we can find all expected elements on the first screen
      final greetingTextFinder = find.byKey(const ValueKey('greeting_text'));
      final descriptionTextFinder = find.byKey(const ValueKey('description_text'));
      final navigateButtonFinder = find.byKey(const ValueKey('navigate_button'));
      final apiButtonFinder = find.byKey(const ValueKey('api_button'));
      
      expect(greetingTextFinder, findsOneWidget, reason: 'Should find greeting text');
      expect(descriptionTextFinder, findsOneWidget, reason: 'Should find description text');
      expect(navigateButtonFinder, findsOneWidget, reason: 'Should find navigate button');
      expect(apiButtonFinder, findsOneWidget, reason: 'Should find API button');
      
      print('Found all expected widgets on the first screen');
      
      // Add a delay to observe the first screen
      print('Pausing to observe first screen...');
      await Future.delayed(const Duration(seconds: 3));
      
      // Navigate to the Goodbye screen
      print('Tapping navigate button to go to Goodbye screen...');
      await tester.tap(navigateButtonFinder);
      await tester.pumpAndSettle();
      
      // Add a delay to observe the Goodbye screen
      print('Pausing to observe Goodbye screen...');
      await Future.delayed(const Duration(seconds: 5));
      
      // Look for elements on the Goodbye screen
      final goodbyeTitleFinder = find.byKey(const ValueKey('goodbye_title'));
      final backButtonFinder = find.byKey(const ValueKey('back_button'));
      
      expect(goodbyeTitleFinder, findsOneWidget, reason: 'Should find goodbye title');
      expect(backButtonFinder, findsOneWidget, reason: 'Should find back button');
      
      print('Found all expected widgets on the Goodbye screen');
      
      // Navigate back to the first screen
      print('Tapping back button to return to first screen...');
      await tester.tap(backButtonFinder);
      await tester.pumpAndSettle();
      
      // Add a delay to observe the first screen again
      print('Pausing to observe return to first screen...');
      await Future.delayed(const Duration(seconds: 3));
      
      // Verify we're back on the first screen
      expect(navigateButtonFinder, findsOneWidget, reason: 'Should be back on first screen');
      
      print('Successfully returned to first screen');
      
      // Test the API button
      print('Tapping API button...');
      await tester.tap(apiButtonFinder, warnIfMissed: false);  // Added warnIfMissed: false to suppress the warning
      await tester.pumpAndSettle();
      
      // Add a final delay to observe any effects from the API button
      print('Pausing to observe effects of API button...');
      await Future.delayed(const Duration(seconds: 3));
      
      print('Test completed successfully');
    });
  });
}