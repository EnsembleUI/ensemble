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
  });
}
