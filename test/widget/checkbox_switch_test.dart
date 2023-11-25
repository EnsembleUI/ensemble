import 'package:ensemble/widget/checkbox.dart';
import 'package:ensemble/widget/switch.dart';
import 'package:ensemble/widget/input/form_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'test_utils.dart';

/// Tests for Checkbox and Switch widget
void main() {
  testWidgets("checkbox", (tester) async {
    EnsembleCheckbox widget = EnsembleCheckbox();
    widget.setProperty('leadingText', 'hello');
    widget.setProperty('trailingText', 'there');

    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));
    Finder checkboxFinder = find.byType(Checkbox);

    // make sure leading/trailing text are shown properly
    expect(find.text('hello'), findsOneWidget);
    expect(find.text('there'), findsOneWidget);
    expect(find.byType(Text), findsNWidgets(2));
    expect(checkboxFinder, findsOneWidget);

    // checkbox should start out unchecked
    Checkbox checkbox = tester.firstWidget(checkboxFinder);
    expect(checkbox.value, false);

    // tap and confirm the checkbox is now checked
    await tester.tap(checkboxFinder);
    await tester.pump();
    checkbox = tester.firstWidget(
        checkboxFinder); // need to get the widget's new reference or it won't work
    expect(checkbox.value, true);
  });

  testWidgets("switch", (tester) async {
    EnsembleSwitch widget = EnsembleSwitch();
    widget.setProperty('value', true);
    widget.setProperty('trailingText', 'hello');

    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));
    Finder switchFinder = find.byType(Switch);

    // should only find 1 instance of Text which is the trailing text
    expect(find.text('hello'), findsOneWidget);
    expect(find.byType(Text), findsOneWidget);
    expect(switchFinder, findsOneWidget);

    // initially switch is ON
    Switch aSwitch = tester.firstWidget(switchFinder);
    expect(aSwitch.value, true);

    // tap and confirm switch is now OFF
    await tester.tap(switchFinder);
    await tester.pump();
    aSwitch = tester.firstWidget(switchFinder);
    expect(aSwitch.value, false);
  });
}
