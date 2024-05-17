import 'package:ensemble/widget/input/dropdown.dart';
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
}
