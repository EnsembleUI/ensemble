import 'dart:developer';
import 'dart:io';

import 'package:ensemble/ensemble.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/widget/input/form_textfield.dart';
import 'package:ensemble/widget/text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../framework/test_helper.dart';

void main() {
  late EnsembleConfig config;
  setUpAll(() async {
    config = await TestHelper.setupApp(appName: 'themedApp');
  });

  group('Theme App Tests', () {
    testWidgets("Test Widgets inheriting from themes", (tester) async {
      await TestHelper.loadScreen(tester, 'Widgets', config);
      await tester.pumpAndSettle();
      // checking default style getting from theme without any overrides
      Finder widget = find.ancestor(
          of: find.text('original'), matching: find.byType(TextField));
      expect(widget, findsOneWidget);
      TextField originalText = tester.firstWidget(widget);

      // by default get from theme.ensemble
      expect(originalText.decoration?.border is UnderlineInputBorder,
          true); // default is underline
      expect(
          (originalText.decoration?.border as UnderlineInputBorder)
              .borderRadius,
          BorderRadius.circular(5));
      expect(originalText.decoration?.border?.borderSide.color,
          const Color(0xFF404040));
      expect(originalText.decoration?.border?.borderSide.width, 1.0);
      expect(originalText.decoration?.focusedBorder?.borderSide.color,
          const Color(0xFF49DEFF));

      // TODO: can we get the actual border style changed if we focus in?
      // vs just checking for the different border types?
      // await tester.tap(widget);
      // await tester.pumpAndSettle();

      // now look update another widget with inline styles
      widget = find.ancestor(
          of: find.text('updated style'), matching: find.byType(TextField));
      expect(widget, findsOneWidget);
      TextField updatedStyleText = tester.firstWidget(widget);
      expect(updatedStyleText.decoration?.border is UnderlineInputBorder, true);
      expect(
          (updatedStyleText.decoration?.border as UnderlineInputBorder)
              .borderRadius,
          BorderRadius.circular(10));
      expect(updatedStyleText.decoration?.border?.borderSide.width, 2.0);
      expect(updatedStyleText.decoration?.border?.borderSide.color,
          const Color(0xFFCFA17B));
      expect(updatedStyleText.decoration?.focusedBorder?.borderSide.color,
          const Color(0xFF86BAA6));

      // find Input with Box style
      widget = find.ancestor(
          of: find.text('box style'), matching: find.byType(TextField));
      expect(widget, findsOneWidget);
      TextField boxStyleText = tester.firstWidget(widget);
      expect(boxStyleText.decoration?.border is OutlineInputBorder, true);
      expect(
          (boxStyleText.decoration?.border as OutlineInputBorder).borderRadius,
          BorderRadius.circular(99));
      expect(boxStyleText.decoration?.border?.borderSide.width, 1.0);
    });
  });
}
