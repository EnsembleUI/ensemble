import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/widget/text.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/layout/box_layout.dart' as ensemble_row;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// Tests for Checkbox and Switch widget
void main() {
  testWidgets("button with label", (tester) async {
    Button widget = Button();
    widget.setProperty('label', 'hello world');

    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));
    Finder buttonFinder = find.byType(ElevatedButton);

    expect(find.text('hello world'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(buttonFinder, findsOneWidget);

    ElevatedButton textButton = tester.firstWidget(buttonFinder);
    expect((textButton.child as Text).data, 'hello world');
  });

  testWidgets("button with label widget", (tester) async {
    Button widget = Button();
    YamlMap labelWidget = YamlMap.wrap({'Row': {'children': [{'Text': {'text': 'hello world' }}]}});
    widget.setProperty('labelWidget', labelWidget);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(widget));
    Finder buttonFinder = find.byType(ElevatedButton);

    expect(find.text('hello world'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(buttonFinder, findsOneWidget);

    ElevatedButton textButton = tester.firstWidget(buttonFinder);
    expect((((textButton.child as DataScopeWidget).child as ensemble_row.Row).controller.children?.first as EnsembleText).getProperty('text'), 'hello world');
  });
}