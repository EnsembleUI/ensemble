import 'package:ensemble_dropdown/ensemble_dropdown.dart';
import 'package:ensemble/widget/input/dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('select a dropdown value and confirm selection', (tester) async {
    Dropdown widget = Dropdown();
    widget.setProperty('items', ['one', 'two', 'three']);

    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));
    Finder dropdownFinder = find.byType(Dropdown);
    expect(dropdownFinder, findsOneWidget);

    // open the dropdown
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    // select the value 'two'
    await tester.tap(find.text('two'));
    await tester.pumpAndSettle();

    // verified value is selected after dropdown has closed
    expect(find.text('two'), findsOneWidget);
  });

  testWidgets('dropdown popup renders a decimal border width', (tester) async {
    final widget = Dropdown()
      ..setProperty('items', ['one'])
      ..setProperty('dropdownBorderColor', 0xFF102030)
      ..setProperty('dropdownBorderWidth', 1.5);

    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));

    final dropdown = tester.firstWidget<EnsembleDropdown<dynamic>>(
        find.byType(EnsembleDropdown<dynamic>));
    final decoration = dropdown.dropdownStyleData.decoration as BoxDecoration;
    expect((decoration.border as Border).top.width, 1.5);
  });
}
