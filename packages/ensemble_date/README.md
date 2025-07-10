# ensemble_date

Dart Extensions for `DateTime`

ensemble_date provides the most comprehensive, yet simple and consistent toolset for manipulating Dart dates.

**This package is a maintained fork of [dart_date](https://pub.dev/packages/dart_date), providing continued updates and improvements.**

Inspired by [date-fns](https://date-fns.org/)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  ensemble_date: ^1.6.0
```

Then run:

```bash
dart pub get
```

## Usage

- Use `instance.method()` for added methods.
- Use `instance.property` for added getter properties.
- Use `Date.method()` for added static methods.
- Use `Date.property` for added static getter properties.

``` bash
DE (String): Heute ist 18-Juni-2020
DE (Date): 2020-06-18 00:00:00.000
ES (Timeago): hace 3 meses
EN (Format): June 18 2020, 8:33:52 AM
.UTC: 2006-06-06 11:06:06.006006Z
Closest to now (2020-06-18 08:33:52.683698): 2020-06-16 08:33:52.610450 (2 days ago)
true
Human String: Thu Nov 20 2014 16:51:30
Yesterday: 2020-06-17 08:33:52.700225
Tomorrow: 2020-06-19 08:33:52.700579
```

```dart
import 'package:ensemble_date/ensemble_date.dart';

  const pattern = '\'Heute ist\' dd-MMMM-yyyy';
  final n = DateTime.now();
  final de_String = DateTime.now().format(pattern, 'de_DE');
  final de_Date = Date.parse(de_String, pattern: pattern, locale: 'de_DE');
  print(
    'DE (String): $de_String',
  );
  print(
    'DE (Date): $de_Date',
  );

  final es_Timeago = DateTime.now().subDays(100).timeago(locale: 'es');
  print("ES (Timeago): $es_Timeago");

  final en_Format = DateTime.now().format('MMMM dd y, h:mm:ss a');
  print("EN (Format): $en_Format");

  final utc = DateTime(2006, 6, 6, 6, 6, 6, 6, 6).UTC;
  print(".UTC: $utc");

  var now = DateTime.now();
  var closest = now.closestTo(
    [
      n.nextWeek,
      n.previousDay.previousDay,
      n.previousWeek.nextDay,
      n.nextMonth,
      n.nextYear,
    ],
  );
  print('Closest to now ($now): $closest (${closest.timeago()})');

  print(Date.today is DateTime);

  print("Human String: " +
      DateTime.parse('2014-11-20T16:51:30.000Z').toHumanString());

  print("Yesterday: " + (Date.today - Duration(days: 1)).toString());
  print("Tomorrow: " + (Date.today + Duration(days: 1)).toString());
```

## LICENSE

[MIT](./LICENSE)

## API

[Check full docs](https://pub.dev/documentation/ensemble_date/latest/)

Date extension on DateTime

### Properties
``` dart
clone → DateTime
endOfDay → DateTime
endOfHour → DateTime
endOfISOWeek → DateTime
endOfMinute → DateTime
endOfMonth → DateTime
endOfSecond → DateTime
endOfWeek → DateTime
endOfYear → DateTime
getDate → int
getDay → int
getDayOfYear → int
getDaysInMonth → int
getDaysInYear → int
getHours → int
getMicroseconds → int
getMicrosecondsSinceEpoch → int
getMilliseconds → int
getMillisecondsSinceEpoch → int
getMinutes → int
getMonth → int
getSeconds → int
getTime → int
getTimeZoneName → String
getTimeZoneOffset → Duration
getWeekday → int
getYear → int
getWeekYear → int
getWeek → int
getISOWeek → int
getISOWeeksInYear → int
isFirstDayOfMonth → bool
isFriday → bool
isFuture → bool
isLastDayOfMonth → bool
isLeapYear → bool
isMonday → bool
isPast → bool
isSaturday → bool
isSunday → bool
isThisHour → bool
isThisMinute → bool
isThisMonth → bool
isThisSecond → bool
isThisYear → bool
isThursday → bool
isToday → bool
isTomorrow → bool
isTuesday → bool
isUTC → bool
isWednesday → bool
isWeekend → bool
isYesterday → bool
local → DateTime
nextDay → DateTime
nextMonth → DateTime
nextWeek → DateTime
nextYear → DateTime
previousDay → DateTime
previousMonth → DateTime
previousWeek → DateTime
previousYear → DateTime
secondsSinceEpoch → int
startOfDay → DateTime
startOfHour → DateTime
startOfISOWeek → DateTime
startOfMinute → DateTime
startOfMonth → DateTime
startOfSecond → DateTime
startOfWeek → DateTime
startOfYear → DateTime
startOfWeekYear → DateTime
startOfISOWeekYear → DateTime
timestamp → int
toLocalTime → DateTime
toUTC → DateTime
utc → DateTime
```

### Methods

``` dart
addDays(int amount) → DateTime
addHours(int amount) → DateTime
addMicroseconds(int amount) → DateTime
addMilliseconds(int amount) → DateTime
addMinutes(int amount) → DateTime
addMonths(int amount) → DateTime
addQuarters(int amount) → DateTime
addSeconds(int amount) → DateTime
addWeeks(int amount) → DateTime
addYears(int amount) → DateTime
closestIndexTo(Iterable<DateTime> datesArray) → int
closestTo(Iterable<DateTime> datesArray) → DateTime
compare(DateTime other) → int
diff(DateTime other) → Duration
differenceInDays(DateTime other) → int
differenceInHours(DateTime other) → int
differenceInMicroseconds(DateTime other) → int
differenceInMilliseconds(DateTime other) → int
differenceInMinutes(DateTime other) → int
differenceInSeconds(DateTime other) → int
eachDay(DateTime date) → Iterable<DateTime>
equals(DateTime other) → bool
format(String pattern, [String locale = 'en_US']) → String
isEqual(dynamic other) → bool
isSameDay(DateTime other) → bool
isSameHour(DateTime other) → bool
isSameMinute(DateTime other) → bool
isSameMonth(DateTime other) → bool
isSameOrAfter(DateTime other) → bool
isSameOrBefore(DateTime other) → bool
isSameSecond(DateTime other) → bool
isSameYear(DateTime other) → bool
isWithinInterval(Interval interval) → bool
isWithinRange(DateTime startDate, DateTime endDate) → bool
setDay(int day, [int hour, int minute, int second, int millisecond, int microsecond]) → DateTime
setHour(int hour, [int minute, int second, int millisecond, int microsecond]) → DateTime
setMicrosecond(int microsecond) → DateTime
setMillisecond(int millisecond, [int microsecond]) → DateTime
setMinute(int minute, [int second, int millisecond, int microsecond]) → DateTime
setMonth(int month, [int day, int hour, int minute, int second, int millisecond, int microsecond]) → DateTime
setSecond(int second, [int millisecond, int microsecond]) → DateTime
setYear(int year, [int month, int day, int hour, int minute, int second, int millisecond, int microsecond]) → DateTime
sub(Duration duration) → DateTime
subDays(int amount) → DateTime
subHours(int amount) → DateTime
subMicroseconds(dynamic amount) → DateTime
subMilliseconds(dynamic amount) → DateTime
subMinutes(dynamic amount) → DateTime
subMonths(dynamic amount) → DateTime
subSeconds(dynamic amount) → DateTime
subtract(Duration duration) → DateTime
subYears(dynamic amount) → DateTime
timeago({String locale, DateTime clock, bool allowFromNow}) → String
toHumanString() → String
```

### Operators

``` dart
operator <(DateTime other) → bool
operator <=(DateTime other) → bool
operator >(DateTime other) → bool
operator >=(DateTime other) → bool
operator -(Duration other) → DateTime
operator +(Duration other) → DateTime
```

### Static Properties

``` dart
endOfToday → DateTime
endOfTomorrow → DateTime
endOfYesterday → DateTime
startOfToday → DateTime
today → DateTime
tomorrow → DateTime
yesterday → DateTime
```

### Static Methods

``` dart
areRangesOverlapping(DateTime initialRangeStartDate, DateTime initialRangeEndDate, DateTime comparedRangeStartDate, DateTime comparedRangeEndDate) → bool
compareAsc(DateTime dateLeft, DateTime dateRight) → int
compareDesc(DateTime dateLeft, DateTime dateRight) → int
fromSecondsSinceEpoch(int secondsSinceEpoch, {bool isUtc: false}) → DateTime
isDate(dynamic argument) → bool
max(DateTime left, DateTime right) → DateTime
min(DateTime left, DateTime right) → DateTime
parse(String dateString, {String pattern, String locale: 'en_US', bool isUTC: false}) → DateTime
unix(int seconds) → DateTime
```

### Interval class

``` dart
// Constructors
Interval(DateTime start, DateTime end)

// Properties
duration → Duration
end → DateTime
hashCode → int
runtimeType → Type
start → DateTime

// Methods
contains(Interval interval) → bool
cross(Interval other) → bool
difference(Interval other) → Interval
equals(Interval other) → bool
includes(DateTime date) → bool
intersection(Interval other) → Interval
symetricDiffetence(Interval other) → List<Interval>
toString() → String
union(Interval other) → Interval

// Operators
operator <(Interval other) → bool
operator <=(Interval other) → bool
operator ==(dynamic other) → bool
operator >(Interval other) → bool
operator >=(Interval other) → bool
```

### Duration Class

``` dart
// Operators
operator -(Duration other) → Duration
operator +(Duration other) → Duration
operator *(num other) → Duration
operator /(num other) → Duration
```
