

import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter_test/flutter_test.dart';

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
    // date formatted as local date
    expect(InvokablePrimitive.prettyDateTime('2022-06-16T12:00:00-0700'), 'Jun 16, 2022 12:00 PM');
    expect(InvokablePrimitive.prettyDate('2022-06-16T12:00:00-0700'), 'Jun 16, 2022');
  });
  
  test('duration', () {
    // 7,000 secs = 1 hr 56 min 40 se
    expect(InvokablePrimitive.prettyDuration(7000), "1 hour 56 minutes");
    expect(InvokablePrimitive.prettyDuration(180654), "2 days 2 hours 10 minutes");
    expect(InvokablePrimitive.prettyDuration(1170654), "1 week 6 days 13 hours 10 minutes");
  });
}