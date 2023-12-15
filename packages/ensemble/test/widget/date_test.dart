import 'package:ensemble/widget/input/form_date.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'test_utils.dart';

/// Tests for Date widget
void main() {
  testWidgets("Date widget with no params", (tester) async {
    await tester.pumpWidget(TestUtils.wrapTestWidget(Date()));
    expect(find.text('Select a date'), findsOneWidget);

    // confirm the date picker appear on tapping the calendar button
    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets("Date widget with initial value", (tester) async {
    var date = '2022-11-23';
    Date dateWidget = Date();
    dateWidget.setProperty('initialValue', date);
    await tester.pumpWidget(TestUtils.wrapTestWidget(dateWidget));

    // confirm the initial date is properly shown and formatted
    expect(find.text(DateFormat.yMMMd().format(DateTime.parse(date))),
        findsOneWidget);

    // confirm the value is in ISO format (same as what we set)
    expect(dateWidget.getProperty('value').toString(), date);
  });
}
