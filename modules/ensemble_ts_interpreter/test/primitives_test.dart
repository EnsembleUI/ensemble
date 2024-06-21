

import 'package:ensemble_ts_interpreter/invokables/invokablecommons.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'test_utils.dart';

void main() {


  test('date parsing', () {
    // output is not UTC/GMT
    expect(InvokablePrimitive.parseDateTime(1654841398)!.toIso8601String(), '2022-06-09T23:09:58.000');
    expect(InvokablePrimitive.parseDateTime('2022-06-16T19:00:00')!.toIso8601String(), '2022-06-16T19:00:00.000');

    // output is UTC/GMT
    expect(InvokablePrimitive.parseDateTime('2022-06-16T19:00:00.000Z')!.toIso8601String(), '2022-06-16T19:00:00.000Z');

    expect(InvokablePrimitive.parseDateTime('2022-06-16T12:00:00-0700')!.toIso8601String(), '2022-06-16T19:00:00.000Z');
    expect(InvokablePrimitive.parseDateTime('Thu, 16 Jun 2022 12:00:00 GMT-0700')!.toIso8601String(), '2022-06-16T19:00:00.000Z');

    expect(InvokablePrimitive.parseDateTime('2022-06-16T12:00:00+0200')!.toIso8601String(), '2022-06-16T10:00:00.000Z');
    expect(InvokablePrimitive.parseDateTime('Thu, 16 Jun 2022 12:00:00 GMT+02:00')!.toIso8601String(), '2022-06-16T10:00:00.000Z');
  });

  test('date formatter', () {
    // date formatter can insert NBSP or NNBSP
    var expected = RegExp(r'Jun 16, 2022, 12:00'+ TestUtils.non_breaking_spaces_regex + r'PM');
    expect(expected.hasMatch(InvokablePrimitive.prettyDateTime('2022-06-16T12:00:00-0700')), isTrue);

    expect(InvokablePrimitive.prettyDate('2022-06-16T12:00:00-0700'), 'Jun 16, 2022');
  });
  
  test('duration', () {
    // 7,000 secs = 1 hr 56 min 40 se
    expect(InvokablePrimitive.prettyDuration(7000), "1 hour 56 minutes");
    expect(InvokablePrimitive.prettyDuration(180654), "2 days 2 hours 10 minutes");
    expect(InvokablePrimitive.prettyDuration(1170654), "1 week 6 days 13 hours 10 minutes");
  });

  test('date object in US', () {
    expect(Date(DateTime.parse("2023-06-12T13:12:44")).methods()["toLocaleDateString"]!(), "6/12/2023");

    var expected = RegExp(r'1:12:44' + TestUtils.non_breaking_spaces_regex + r'PM');
    expect(expected.hasMatch(Date(DateTime.parse("2023-06-12T13:12:44")).methods()["toLocaleTimeString"]!()), isTrue);

    expected = RegExp(r'6/12/2023, 1:12:44' + TestUtils.non_breaking_spaces_regex + r'PM');
    expect(expected.hasMatch(Date(DateTime.parse("2023-06-12T13:12:44")).methods()["toLocaleString"]!()), isTrue);
  });

  test('date object in Spanish Europe', () async {
    // needed for testing
    await initializeDateFormatting('es', null);

    expect(Date(DateTime.parse("2023-06-12T13:12:44")).methods()["toLocaleDateString"]!("es"), "12/6/2023");
    expect(Date(DateTime.parse("2023-06-12T13:12:44")).methods()["toLocaleTimeString"]!("es"), "13:12:44");
    expect(Date(DateTime.parse("2023-06-12T13:12:44")).methods()["toLocaleString"]!("es"), "12/6/2023, 13:12:44");
  });
}