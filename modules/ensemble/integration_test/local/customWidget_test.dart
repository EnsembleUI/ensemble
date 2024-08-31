import 'package:ensemble/ensemble.dart';
import 'package:ensemble/widget/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../framework/test_helper.dart';

void main() {
  late EnsembleConfig config;
  setUpAll(() async {
    config = await TestHelper.setupApp(appName: 'widgets');
  });

  group('Custom Widgets', () {
    testWidgets("test basic widget features", (tester) async {
      await TestHelper.loadScreen(tester, 'Custom Widget', config);

      // test visibility
      expect(find.text('I am visible'), findsOneWidget);
      expect(find.text('I am really visible'), findsOneWidget);
      expect(find.text('I am invisible'), findsNothing);

      await tester.tap(find.descendant(
          of: find.byType(Button), matching: find.text('Toggle Visibility')));
      await tester.pumpAndSettle();
      expect(find.text('I am visible'), findsNothing);
      expect(find.text('I am really visible'), findsNothing);
      expect(find.text('I am invisible'), findsOneWidget);

      // test flex and its modification

      // equal distribution with default flex
      expect(tester.getSize(find.text("hello")).width,
          tester.getSize(find.text("world")).width);

      // changing flex under FlexBox is a problem because the parent FlexBox already
      // make the child Expanded if not specified, so if we update it later, there will
      // be duplicate Expanded.
      // ALmost like we want to travel up to the Flexbox and ask it to refresh itself,
      // but that is not recommended. TODO: figure this out
      // change "world" to 2x
      // await tester.tap(find.descendant(
      //     of: find.byType(Button), matching: find.text('Change Flex')));
      // await tester.pumpAndSettle();
      // expect(tester.getSize(find.text("hello")).width, 100);
      // expect(tester.getSize(find.text("world")).width, 200);

      expect(tester.getSize(find.text("1x")).width, 100);
      expect(tester.getSize(find.text("2x")).width, 200);
    });

    testWidgets("onLoad should be called for both new and re-used widget state",
        (tester) async {
      await TestHelper.loadScreen(tester, 'Custom Widget - onLoad', config);

      // after API called, widget's onLoad will change text to "hello"
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(find.text('hello'), findsOneWidget);

      // change the text to "Hi", then open and close bottom sheet, which will invoke the API again
      await tester.tap(find.descendant(
          of: find.byType(Button), matching: find.text("Say Hi")));
      await tester.pumpAndSettle();
      expect(find.text('hi'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.byType(Button), matching: find.text("Show Bottom Sheet")));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(Button), matching: find.text("Close")));
      await tester.pumpAndSettle();

      // since modal's dismiss invoke the API, the Row should re-render. The child widget inside is re-created
      // Regardless if the widget state is reused or not (it should re-use), onLoad should be called again, which
      // is exactly what we are trying to confirm here since the text should be changed back to "hello"
      expect(find.text('hello'), findsOneWidget);
    });
  });
}
