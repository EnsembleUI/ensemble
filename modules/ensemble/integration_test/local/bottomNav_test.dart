import 'dart:math';

import 'package:ensemble/ensemble.dart';
import 'package:flutter_test/flutter_test.dart';

import '../framework/test_helper.dart';

void main() {
  late EnsembleConfig config;
  setUp(() async {
    config = await TestHelper.setupApp(appName: 'bottomNav');
  });

  // Change Home tab content, navigate away then navigate back
  Future<void> _changeHomeTabAndRevisit(WidgetTester tester) async {
    // ensure the text changed from "This is Home" to "Hello World"
    expect(find.text("This is Home"), findsOneWidget);
    await tester.tap(find.text("Change Text"));
    await tester.pumpAndSettle();
    expect(find.text("This is Home"), findsNothing);
    expect(find.text("Hello World"), findsOneWidget);

    // navigate to Profile tab
    await tester.tap(find.text("Profile"));
    await tester.pumpAndSettle();

    // navigate back to Home and confirm the text is reset to the original (since the tab reloads)
    await tester.tap(find.text("Home"));
    await tester.pumpAndSettle();
  }

  group('Test BottomNavBar', () {
    testWidgets(
        "test BottomNavBar with reloadView should always re-render pages on revisit",
        (tester) async {
      await TestHelper.loadScreen(tester, 'BottomNavWithReloadView', config);

      await _changeHomeTabAndRevisit(tester);
      // confirm the Home content is brand new and not changed
      expect(find.text("This is Home"), findsOneWidget);
    });

    testWidgets(
        "test BottomNavBar with reloadView=false should re-use pages on revisit",
        (tester) async {
      await TestHelper.loadScreen(tester, 'BottomNavWithCachedView', config);

      await _changeHomeTabAndRevisit(tester);
      // confirm the text is the changed text, meaning the tab is re-use
      expect(find.text("Hello World"), findsOneWidget);
    });
  });
}
