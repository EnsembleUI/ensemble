import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/widget/ensemble_icon.dart';
import 'package:ensemble/widget/text.dart';
import 'package:ensemble/widget/button.dart';
import 'package:ensemble/layout/box/box_layout.dart' as ensemble_row;
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
    Finder buttonFinder = find.byType(FilledButton);

    expect(find.text('hello world'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(buttonFinder, findsOneWidget);

    FilledButton textButton = tester.firstWidget(buttonFinder);
    expect((textButton.child as Text).data, 'hello world');
  });

  testWidgets("button with starting icon", (tester) async {
    Button widget = Button();
    YamlMap startingIcon = YamlMap.wrap({'name': 'star'});
    widget.setProperty('label', 'hello world');
    widget.setProperty('startingIcon', startingIcon);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(widget));
    Finder buttonFinder = find.byType(FilledButton);

    expect(find.text('hello world'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(buttonFinder, findsOneWidget);

    FilledButton textButton = tester.firstWidget(buttonFinder);
    List<Widget> children = (textButton.child as Row).children;
    expect((children[0] as Icon).icon, Icons.star);
    expect((children[1] as Text).data, 'hello world');
  });
}
