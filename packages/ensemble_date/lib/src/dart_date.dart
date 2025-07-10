import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago_lib;

class Interval {
  late final DateTime _start;
  late final Duration _duration;

  Interval(DateTime start, DateTime end) {
    if (start.isAfter(end)) {
      throw RangeError('Invalid Range');
    }
    _start = start;
    _duration = end.difference(start);
  }

  Duration get duration => _duration;

  DateTime get start => _start;

  DateTime get end => _start.add(_duration);

  Interval setStart(DateTime val) => Interval(val, end);
  Interval setEnd(DateTime val) => Interval(start, val);
  Interval setDuration(Duration val) => Interval(start, start.add(duration));

  bool includes(DateTime date) =>
      (date.isAfter(start) || date.isAtSameMomentAs(start)) &&
      (date.isBefore(end) || date.isAtSameMomentAs(end));

  bool contains(Interval interval) =>
      includes(interval.start) && includes(interval.end);

  bool cross(Interval other) => includes(other.start) || includes(other.end);

  bool equals(Interval other) =>
      start.isAtSameMomentAs(other.start) && end.isAtSameMomentAs(other.end);

  Interval union(Interval other) {
    if (cross(other)) {
      if (end.isAfter(other.start) || end.isAtSameMomentAs(other.start)) {
        return Interval(start, other.end);
      } else if (other.end.isAfter(start) ||
          other.end.isAtSameMomentAs(start)) {
        return Interval(other.start, end);
      } else {
        throw RangeError('Error this: $this; other: $other');
      }
    } else {
      throw RangeError('Intervals don\'t cross');
    }
  }

  Interval intersection(Interval other) {
    if (cross(other)) {
      if (end.isAfter(other.start) || end.isAtSameMomentAs(other.start)) {
        return Interval(other.start, end);
      } else if (other.end.isAfter(start) ||
          other.end.isAtSameMomentAs(start)) {
        return Interval(other.start, end);
      } else {
        throw RangeError('Error this: $this; other: $other');
      }
    } else {
      throw RangeError('Intervals don\'t cross');
    }
  }

  Interval? difference(Interval other) {
    if (other == this) {
      return null;
    } else if (this <= other) {
      // | this | | other |
      if (end.isBefore(other.start)) {
        return this;
      } else {
        return Interval(start, other.start);
      }
    } else if (this >= other) {
      // | other | | this |
      if (other.end.isBefore(start)) {
        return this;
      } else {
        return Interval(other.end, end);
      }
    } else {
      throw RangeError('Error this: $this; other: $other');
    }
  }

  List<Interval?> symetricDiffetence(Interval other) {
    final list = <Interval?>[null, null];
    try {
      list[0] = difference(other);
    } catch (e) {
      list[0] = null;
    }
    try {
      list[1] = other.difference(this);
    } catch (e) {
      list[1] = null;
    }
    return list;
  }

  // Operators
  bool operator <(Interval other) => start.isBefore(other.start);

  bool operator <=(Interval other) =>
      start.isBefore(other.start) || start.isAtSameMomentAs(other.start);

  bool operator >(Interval other) => end.isAfter(other.end);

  bool operator >=(Interval other) =>
      end.isAfter(other.end) || end.isAtSameMomentAs(other.end);

  @override
  String toString() => '<${start} | ${end} | ${duration} >';
}

const int MILLISECONDS_IN_WEEK = 604800000;

extension Date on DateTime {
  /// Number of seconds since epoch time / A.K.A Unix timestamp
  ///
  /// The Unix epoch (or Unix time or POSIX time or Unix timestamp) is the number of
  /// seconds that have elapsed since January 1, 1970 (midnight UTC/GMT), not counting
  /// leap seconds (in ISO 8601: 1970-01-01T00:00:00Z).
  /// Literally speaking the epoch is Unix time 0 (midnight 1/1/1970).
  static DateTime fromSecondsSinceEpoch(
    int secondsSinceEpoch, {
    bool isUtc = false,
  }) =>
      DateTime.fromMillisecondsSinceEpoch(
        secondsSinceEpoch * 1000,
        isUtc: isUtc,
      );

  /// Transforms a date that follows a pattern from a [String] representation to a [DateTime] object
  static DateTime parse(
    String dateString, {
    String? pattern,
    String locale = 'en_US',
    bool isUTC = false,
  }) {
    initializeDateFormatting();
    return pattern == null
        ? DateTime.parse(dateString)
        : DateFormat(pattern, locale).parse(dateString, isUTC);
  }

  /// Create a [Date] object from a Unix timestamp
  static DateTime unix(int seconds) => fromSecondsSinceEpoch(seconds);

  /// Tomorrow at same hour / minute / second than now
  static DateTime get tomorrow => DateTime.now().nextDay;

  /// Yesterday at same hour / minute / second than now
  static DateTime get yesterday => DateTime.now().previousDay;

  /// Current date (Same as [Date.now])
  static DateTime get today => DateTime.now();

  /// Get [Date] object as UTC of current object.
  DateTime get toUTC => toUtc();

  /// Get [Date] object in LocalTime of current object.
  DateTime get toLocalTime => toLocal();

  /// Creates a new [DateTime] instance with the same value as this one
  ///
  /// Returns an exact copy of this [DateTime] preserving the isUtc flag and all time components.
  DateTime get clone => DateTime.fromMicrosecondsSinceEpoch(
        microsecondsSinceEpoch,
        isUtc: isUtc,
      );

  // /// Add a [Duration] to this date
  // DateTime add(Duration duration) {
  //   return add(duration);
  // }

  /// Substract a [Duration] to this date
  DateTime subtract(Duration duration) => add(Duration.zero - duration);

  /// Get the difference between this data and other date as a [Duration]
  Duration diff(DateTime other) => difference(other);

  /// Add a certain amount of days to this date
  DateTime addDays(int amount, [bool ignoreDaylightSavings = false]) =>
      ignoreDaylightSavings
          ? DateTime(year, month, day + amount, hour, minute, second,
              millisecond, microsecond)
          : add(Duration(days: amount));

  /// Add a certain amount of hours to this date
  DateTime addHours(int amount, [bool ignoreDaylightSavings = false]) =>
      ignoreDaylightSavings
          ? DateTime(year, month, day, hour + amount, minute, second,
              millisecond, microsecond)
          : add(Duration(hours: amount));

  // TODO: this
  // Date addISOYears(int amount) {
  //   return this;
  // }

  /// Add a certain amount of milliseconds to this date
  DateTime addMilliseconds(int amount) => add(Duration(milliseconds: amount));

  /// Add a certain amount of microseconds to this date
  DateTime addMicroseconds(int amount) => add(Duration(microseconds: amount));

  /// Add a certain amount of minutes to this date
  DateTime addMinutes(int amount, [bool ignoreDaylightSavings = false]) =>
      ignoreDaylightSavings
          ? DateTime(year, month, day, hour, minute + amount, second,
              millisecond, microsecond)
          : add(Duration(minutes: amount));

  /// Add a certain amount of months to this date
  DateTime addMonths(int amount) => clone.setMonth(month + amount);

  /// Add a certain amount of quarters to this date
  DateTime addQuarters(int amount) => addMonths(amount * 3);

  /// Add a certain amount of seconds to this date
  DateTime addSeconds(int amount, [bool ignoreDaylightSavings = false]) =>
      ignoreDaylightSavings
          ? DateTime(year, month, day, hour, minute, second + amount,
              millisecond, microsecond)
          : add(Duration(seconds: amount));

  /// Add a certain amount of weeks to this date
  DateTime addWeeks(int amount) => addDays(amount * 7);

  /// Add a certain amount of years to this date
  DateTime addYears(int amount) => clone.setYear(year + amount);

  /// Know if two ranges of dates overlaps
  static bool areRangesOverlapping(
    DateTime initialRangeStartDate,
    DateTime initialRangeEndDate,
    DateTime comparedRangeStartDate,
    DateTime comparedRangeEndDate,
  ) {
    if (initialRangeStartDate.isAfter(initialRangeEndDate)) {
      throw RangeError('Not valid initial range');
    }

    if (comparedRangeStartDate.isAfter(comparedRangeEndDate)) {
      throw RangeError('Not valid compareRange range');
    }

    final initial = Interval(initialRangeStartDate, initialRangeEndDate);
    final compared = Interval(comparedRangeStartDate, comparedRangeEndDate);

    return initial.cross(compared) || compared.cross(initial);
  }

  /// Get index of the closest day to current one, returns null if empty [Iterable] is passed as argument
  int? closestIndexTo(Iterable<DateTime> datesArray) {
    final differences = datesArray.map((date) {
      return date.difference(this).abs();
    });

    if (datesArray.isEmpty) {
      return null;
    }

    var index = 0;
    for (var i = 0; i < differences.length; i++) {
      if (differences.elementAt(i) < differences.elementAt(index)) {
        index = i;
      }
    }
    return index;
  }

  /// Get closest day to current one, returns null if empty [Iterable] is passed as argument
  DateTime? closestTo(Iterable<DateTime> datesArray) {
    if (datesArray.isEmpty) {
      return null;
    }
    final index = closestIndexTo(datesArray);
    if (index == null) {
      return null;
    }

    return datesArray.elementAt(index);
  }

  /// Compares this Date object to [other],
  /// returning zero if the values are equal.
  /// Returns a negative value if this Date [isBefore] [other]. It returns 0
  /// if it [isAtSameMomentAs] [other], and returns a positive value otherwise
  /// (when this [isAfter] [other]).
  int compare(DateTime other) => compareTo(other);

  /// Returns true if left [isBefore] than right
  static DateTime min(DateTime left, DateTime right) =>
      (left < right) ? left : right;

  /// Returns true if left [isAfter] than right
  static DateTime max(DateTime left, DateTime right) =>
      (left < right) ? right : left;

  /// Compare the two dates and return 1 if the first date [isAfter] the second,
  /// -1 if the first date [isBefore] the second or 0 first date [isEqual] the second.
  static int compareAsc(DateTime dateLeft, DateTime dateRight) {
    if (dateLeft.isAfter(dateRight)) {
      return 1;
    } else if (dateLeft.isBefore(dateRight)) {
      return -1;
    } else {
      return 0;
    }
  }

  /// Compare the two dates and return -1 if the first date [isAfter] the second,
  /// 1 if the first date [isBefore] the second or 0 first date [isEqual] the second.
  static int compareDesc(DateTime dateLeft, DateTime dateRight) =>
      (-1) * compareAsc(dateLeft, dateRight);

  // int differenceInCalendarDays(dateLeft, dateRight)
  // int differenceInCalendarISOWeeks(dateLeft, dateRight)
  // int differenceInCalendarISOYears(dateLeft, dateRight)
  // int differenceInCalendarMonths(dateLeft, dateRight)
  // int differenceInCalendarQuarters(dateLeft, dateRight)
  // int differenceInCalendarWeeks(dateLeft, dateRight, [options])
  // int differenceInCalendarYears(dateLeft, dateRight)
  // int differenceInISOYears(dateLeft, dateRight)

  /// Difference in microseconds between this date and other
  int differenceInMicroseconds(DateTime other) => diff(other).inMicroseconds;

  /// Difference in milliseconds between this date and other
  int differenceInMilliseconds(DateTime other) => diff(other).inMilliseconds;

  /// Difference in minutes between this date and other
  int differenceInMinutes(DateTime other) => diff(other).inMinutes;

  /// Difference in seconds between this date and other
  int differenceInSeconds(DateTime other) => diff(other).inSeconds;

  /// Difference in hours between this date and other
  int differenceInHours(DateTime other) => diff(other).inHours;

  /// Difference in days between this date and other
  int differenceInDays(DateTime other) => diff(other).inDays;

  // int differenceInMonths(dateLeft, dateRight)
  // int differenceInQuarters(dateLeft, dateRight)
  // int differenceInWeeks(dateLeft, dateRight)
  // int differenceInYears(dateLeft, dateRight)

  /// Formats provided [date] to a fuzzy time like 'a moment ago' (use timeago package to change locales)
  ///
  /// - If [locale] is passed will look for message for that locale, if you want
  ///   to add or override locales use [setLocaleMessages]. Defaults to 'en'
  /// - If [clock] is passed this will be the point of reference for calculating
  ///   the elapsed time. Defaults to DateTime.now()
  /// - If [allowFromNow] is passed, format will use the From prefix, ie. a date
  ///   5 minutes from now in 'en' locale will display as '5 minutes from now'
  /// If locales was not loaded previously en would be used use timeago.setLocaleMessages to set them
  String timeago({String? locale, DateTime? clock, bool? allowFromNow}) =>
      timeago_lib.format(
        this,
        locale: locale,
        clock: clock,
        allowFromNow: allowFromNow ?? false,
      );

  /// Return the array of dates within the specified range.
  Iterable<DateTime> eachDay(DateTime date) sync* {
    if (isSameDay(date)) {
      yield date.startOfDay;
    } else {
      final difference = diff(date);
      final days = difference.abs().inDays;
      var current = date.startOfDay;
      if (difference.isNegative) {
        for (var i = 0; i < days; i++) {
          yield current;
          current = current.nextDay;
        }
      } else {
        for (var i = 0; i < days; i++) {
          yield current;
          current = current.nextDay;
        }
      }
    }
  }

  /// Return the end of a day for this date. The result will be in the local timezone.
  DateTime get endOfDay => clone.setHour(23, 59, 59, 999, 999);

  /// Return the end of the hour for this date. The result will be in the local timezone.
  DateTime get endOfHour => clone.setMinute(59, 59, 999, 999);

  /// Return the end of ISO week for this date. The result will be in the local timezone.
  DateTime get endOfISOWeek => startOfISOWeek.addDays(6).endOfDay;

  // DateTime endOfISOYear()

  /// Return the end of the minute for this date. The result will be in the local timezone.
  DateTime get endOfMinute => clone.setSecond(59, 999, 999);

  /// Return the end of the month for this date. The result will be in the local timezone.
  DateTime get endOfMonth => DateTime(year, month + 1).subMicroseconds(1);

  // Date endOfQuarter()

  /// Return the end of the second for this date. The result will be in the local timezone.
  DateTime get endOfSecond => clone.setMillisecond(999, 999);

  /// Return the end of today. The result will be in the local timezone.
  static DateTime get endOfToday => DateTime.now().endOfDay;

  /// Return the end of tomorrow. The result will be in the local timezone.
  static DateTime get endOfTomorrow => DateTime.now().nextDay.endOfDay;

  /// Return the end of yesterday. The result will be in the local timezone.
  static DateTime get endOfYesterday => DateTime.now().previousDay.endOfDay;

  /// Return the end of the week for this date. The result will be in the local timezone.
  DateTime get endOfWeek => nextWeek.startOfWeek.subMicroseconds(1);

  /// Return the end of the year for this date. The result will be in the local timezone.
  DateTime get endOfYear => clone.setYear(year, DateTime.december).endOfMonth;

  /// Get the day of the month of the given date.
  /// The day of the month 1..31.
  int get getDate => day;

  /// Get the day of the week of the given date.
  int get getDay => weekday;

  /// Days since year started. The result will be in the local timezone.
  int get getDayOfYear => diff(startOfYear).inDays + 1;

  /// Days since month started. The result will be in the local timezone.
  int get getDaysInMonth => endOfMonth.diff(startOfMonth).inDays + 1;

  /// Number of days in current year
  int get getDaysInYear => endOfYear.diff(startOfYear).inDays + 1;

  /// Get the hours of the given date.
  /// The hour of the day, expressed as in a 24-hour clock 0..23.
  int get getHours => hour;

  // int getISODay(date)
  // int getISOYear(date)

  /// Get the milliseconds of the given date.
  /// The millisecond 0...999.
  int get getMilliseconds => millisecond;

  /// Get the microseconds of the given date.
  /// The microsecond 0...999.
  int get getMicroseconds => microsecond;

  /// Get the milliseconds since the 'Unix epoch' 1970-01-01T00:00:00Z (UTC).
  int get getMillisecondsSinceEpoch => millisecondsSinceEpoch;

  /// Get the microseconds since the 'Unix epoch' 1970-01-01T00:00:00Z (UTC).
  int get getMicrosecondsSinceEpoch => microsecondsSinceEpoch;

  /// Get the minutes of the given date.
  /// The minute 0...59.
  int get getMinutes => minute;

  /// Get the month of the given date.
  /// The month 1..12.
  int get getMonth => month;

  // int getOverlappingDaysInRanges(initialRangeStartDate, initialRangeEndDate, comparedRangeStartDate, comparedRangeEndDate)
  // int getQuarter(date)

  /// Get the seconds of the given date.
  /// The second 0...59.
  int get getSeconds => second;

  /// get the numer of milliseconds since epoch
  int get timestamp => millisecondsSinceEpoch;

  /// get the numer of milliseconds since epoch
  int get getTime => millisecondsSinceEpoch;

  /// The year
  int get getYear => year;

  /// The time zone name.
  /// This value is provided by the operating system and may be an abbreviation or a full name.
  /// In the browser or on Unix-like systems commonly returns abbreviations, such as 'CET' or 'CEST'.
  /// On Windows returns the full name, for example 'Pacific Standard Time'.
  String get getTimeZoneName => timeZoneName;

  /// The time zone offset, which is the difference between local time and UTC.
  /// The offset is positive for time zones east of UTC.
  /// Note, that JavaScript, Python and C return the difference between UTC and local time.
  /// Java, C# and Ruby return the difference between local time and UTC.
  Duration get getTimeZoneOffset => timeZoneOffset;

  /// The day of the week monday..sunday.
  /// In accordance with ISO 8601 a week starts with Monday, which has the value 1.
  int get getWeekday => weekday;

  /// Get the week index
  int get getWeek => addDays(1).getISOWeek;

  /// Get the ISO week index
  int get getISOWeek {
    final woy = ((_ordinalDate - weekday + 10) ~/ 7);

    // If the week number equals zero, it means that the given date belongs to the preceding (week-based) year.
    if (woy == 0) {
      // The 28th of December is always in the last week of the year
      return DateTime(year - 1, 12, 28).getISOWeek;
    }

    // If the week number equals 53, one must check that the date is not actually in week 1 of the following year
    if (woy == 53 &&
        DateTime(year, 1, 1).weekday != DateTime.thursday &&
        DateTime(year, 12, 31).weekday != DateTime.thursday) {
      return 1;
    }

    return woy;
  }

  int get _ordinalDate {
    const offsets = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334];
    return offsets[month - 1] + day + (isLeapYear && month > 2 ? 1 : 0);
  }

  /// Get the local week-numbering year
  int get getWeekYear {
    final startOfNextYear = DateTime(year + 1).startOfWeek;

    if (millisecondsSinceEpoch >= startOfNextYear.millisecondsSinceEpoch) {
      return year + 1;
    } else {
      final startOfThisYear = DateTime(year).startOfWeek;

      if (millisecondsSinceEpoch >= startOfThisYear.millisecondsSinceEpoch) {
        return year;
      } else {
        return year - 1;
      }
    }
  }

  /// Return true if other [isEqual] or [isAfter] to this date
  bool isSameOrAfter(DateTime other) => this == other || isAfter(other);

  /// Return true if other [isEqual] or [isBefore] to this date
  bool isSameOrBefore(DateTime other) => this == other || isBefore(other);

  /// Check if a Object if a [DateTime], use for validation purposes
  static bool isDate(argument) => argument is DateTime;

  /// Check if a date is [equals] to other
  bool isEqual(dynamic other) {
    if (other is DateTime) {
      return equals(other);
    }
    return false;
  }

  /// Return true if this date day is monday
  bool get isMonday => weekday == DateTime.monday;

  /// Return true if this date day is tuesday
  bool get isTuesday => weekday == DateTime.tuesday;

  /// Return true if this date day is wednesday
  bool get isWednesday => weekday == DateTime.wednesday;

  /// Return true if this date day is thursday
  bool get isThursday => weekday == DateTime.thursday;

  /// Return true if this date day is friday
  bool get isFriday => weekday == DateTime.friday;

  /// Return true if this date day is saturday
  bool get isSaturday => weekday == DateTime.saturday;

  /// Return true if this date day is sunday
  bool get isSunday => weekday == DateTime.sunday;

  /// Is the given date the first day of a month?
  bool get isFirstDayOfMonth => isSameDay(startOfMonth);

  /// Return true if this date [isAfter] [Date.now]
  bool get isFuture => isAfter(DateTime.now());

  /// Is the given date the last day of a month?
  bool get isLastDayOfMonth =>
      isSameDay(nextMonth.startOfMonth.subHours(12).startOfDay);

  /// Is the given date in the leap year?
  bool get isLeapYear => year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);

  /// Return true if this date [isBefore] [Date.now]
  bool get isPast => isBefore(DateTime.now());

  /// Check if this date is in the same day than other
  bool isSameDay(DateTime other) => startOfDay == other.startOfDay;

  /// Check if this date is in the same hour than other
  bool isSameHour(DateTime other) => startOfHour == other.startOfHour;

  // bool isSameISOWeek(dateLeft, dateRight)
  // bool isSameISOYear(dateLeft, dateRight)

  /// Check if this date is in the same minute than other
  bool isSameMinute(DateTime other) => startOfMinute == other.startOfMinute;

  /// Check if this date is in the same month than other
  bool isSameMonth(DateTime other) => startOfMonth == other.startOfMonth;

  // bool isSameQuarter(dateLeft, dateRight)

  /// Check if this date is in the same second than other
  bool isSameSecond(DateTime other) =>
      secondsSinceEpoch == other.secondsSinceEpoch;

  // bool isSameWeek(dateLeft, dateRight, [options])

  /// Check if this date is in the same year than other
  bool isSameYear(DateTime other) => year == other.year;

  /// Check if this date is in the same hour than [DateTime.now]
  bool get isThisHour => startOfHour == today.startOfHour;

  // bool isThisISOWeek()
  // bool isThisISOYear()

  /// Check if this date is in the same minute than [DateTime.now]
  bool get isThisMinute => startOfMinute == today.startOfMinute;

  /// Check if this date is in the same month than [DateTime.now]
  bool get isThisMonth => isSameMonth(today);

  // bool isThisQuarter()

  /// Check if this date is in the same second than [DateTime.now]
  bool get isThisSecond => isSameSecond(today);

  // bool isThisWeek(, [options])

  /// Check if this date is in the same year than [DateTime.now]
  bool get isThisYear => isSameYear(today);

  // bool isValid()

  /// Check if this date is in the same day than [DateTime.today]
  bool get isToday => isSameDay(today);

  /// Check if this date is in the same day than [DateTime.tomorrow]
  bool get isTomorrow => isSameDay(tomorrow);

  /// Check if this date is in the same day than [DateTime.yesterday]
  bool get isYesterday => isSameDay(yesterday);

  /// Return true if this [DateTime] is set as UTC.
  bool get isUTC => isUtc;

  /// Return true if this [DateTime] is a saturday or a sunday
  bool get isWeekend => day == DateTime.saturday || day == DateTime.sunday;

  /// Checks if a [DateTime] is within a Rage (two dates that makes an [Interval])
  bool isWithinRange(DateTime startDate, DateTime endDate) =>
      Interval(startDate, endDate).includes(this);

  /// Checks if a [DateTime] is within an [Interval]
  bool isWithinInterval(Interval interval) => interval.includes(this);

  // DateTime lastDayOfISOWeek(date)
  // DateTime lastDayOfISOYear(date)
  // DateTime lastDayOfMonth(date)
  // DateTime lastDayOfQuarter(date)
  // DateTime lastDayOfWeek(date, [options])
  // DateTime lastDayOfYear(date)
  // static DateTime max(Iterable<DateTime>)
  // static DateTime min(Iterable<DateTime>)
  // static DateTime parse(any)
  // DateTime setDate(date, dayOfMonth)
  // DateTime setDayOfYear(date, dayOfYear)
  // DateTime setISODay(date, day)
  // DateTime setISOWeek(date, isoWeek)
  // DateTime setISOYear(date, isoYear)

  /// Change [year] of this date
  ///
  /// set [month] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [day] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [hour] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [minute] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [second] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [millisecond] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [microsecond] if you want to change it as well
  DateTime setYear(
    int year, [
    int? month,
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
  ]) =>
      DateTime(
        year,
        month ?? this.month,
        day ?? this.day,
        hour ?? this.hour,
        minute ?? this.minute,
        second ?? this.second,
        millisecond ?? this.millisecond,
        microsecond ?? this.microsecond,
      );

  /// Change [month] of this date
  ///
  /// set [day] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [hour] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [minute] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [second] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [millisecond] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [microsecond] if you want to change it as well
  DateTime setMonth(
    int month, [
    int? day,
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
  ]) =>
      DateTime(
        year,
        month,
        day ?? this.day,
        hour ?? this.hour,
        minute ?? this.minute,
        second ?? this.second,
        millisecond ?? this.millisecond,
        microsecond ?? this.microsecond,
      );

  /// Change [day] of this date
  ///
  /// set [hour] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [minute] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [second] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [millisecond] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [microsecond] if you want to change it as well
  DateTime setDay(
    int day, [
    int? hour,
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
  ]) =>
      DateTime(
        year,
        month,
        day,
        hour ?? this.hour,
        minute ?? this.minute,
        second ?? this.second,
        millisecond ?? this.millisecond,
        microsecond ?? this.microsecond,
      );

  /// Change [hour] of this date
  ///
  /// set [minute] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [second] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [millisecond] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [microsecond] if you want to change it as well
  DateTime setHour(
    int hour, [
    int? minute,
    int? second,
    int? millisecond,
    int? microsecond,
  ]) =>
      DateTime(
        year,
        month,
        day,
        hour,
        minute ?? this.minute,
        second ?? this.second,
        millisecond ?? this.millisecond,
        microsecond ?? this.microsecond,
      );

  /// Change [minute] of this date
  ///
  /// set [second] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [millisecond] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [microsecond] if you want to change it as well
  DateTime setMinute(
    int minute, [
    int? second,
    int? millisecond,
    int? microsecond,
  ]) =>
      DateTime(
        year,
        month,
        day,
        hour,
        minute,
        second ?? this.second,
        millisecond ?? this.millisecond,
        microsecond ?? this.microsecond,
      );

  /// Change [second] of this date
  ///
  /// set [millisecond] if you want to change it as well, to skip an change other optional field set it as [null]
  /// set [microsecond] if you want to change it as well
  DateTime setSecond(
    int second, [
    int? millisecond,
    int? microsecond,
  ]) =>
      DateTime(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond ?? this.millisecond,
        microsecond ?? this.microsecond,
      );

  /// Change [millisecond] of this date
  ///
  /// set [microsecond] if you want to change it as well
  DateTime setMillisecond(
    int millisecond, [
    int? microsecond,
  ]) =>
      DateTime(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
        microsecond ?? this.microsecond,
      );

  /// Change [microsecond] of this date
  DateTime setMicrosecond(
    int microsecond,
  ) =>
      DateTime(
        year,
        month,
        day,
        hour,
        minute,
        second,
        millisecond,
        microsecond,
      );

  // DateTime setQuarter(quarter)

  /// Get a [DateTime] representing start of Day of this [DateTime] in local time.
  DateTime get startOfDay => clone.setHour(0, 0, 0, 0, 0);

  /// Get a [DateTime] representing start of Hour of this [DateTime] in local time.
  DateTime get startOfHour => clone.setMinute(0, 0, 0, 0);

  /// Get a [DateTime] representing start of week (ISO week) of this [DateTime] in local time.
  DateTime get startOfISOWeek => subDays(weekday - 1).startOfDay;

  // DateTime startOfISOYear()

  /// Get a [DateTime] representing start of minute of this [DateTime] in local time.
  DateTime get startOfMinute => clone.setSecond(0, 0, 0);

  /// Get a [DateTime] representing start of month of this [DateTime] in local time.
  DateTime get startOfMonth => clone.setDay(1, 0, 0, 0, 0, 0);

  // DateTime startOfQuarter()
  /// Get a [DateTime] representing start of second of this [DateTime] in local time.
  DateTime get startOfSecond => clone.setMillisecond(0, 0);

  /// Get a [DateTime] representing start of today of [DateTime.today] in local time.
  static DateTime get startOfToday => today.startOfDay;

  /// Get a [DateTime] representing start of week of this [DateTime] in local time.
  DateTime get startOfWeek =>
      weekday == DateTime.sunday ? startOfDay : subDays(weekday).startOfDay;

  /// Get a [DateTime] representing start of year of this [DateTime] in local time.
  DateTime get startOfYear =>
      clone.setMonth(DateTime.january, 1, 0, 0, 0, 0, 0);

  /// Get the start of a local week-numbering year
  DateTime get startOfWeekYear => startOfYear.startOfWeek;

  /// Get the start of a local week-numbering year
  DateTime get startOfISOWeekYear => startOfYear.startOfISOWeek;

  /// Get the number of weeks in an ISO week-numbering year
  int get getISOWeeksInYear {
    return DateTime(year, 12, 28).getISOWeek;
  }

  /// Subtracts a [Duration] from this [DateTime]
  DateTime sub(Duration duration) => add(Duration.zero - duration);

  /// Subtracts an amout of hours from this [DateTime]
  DateTime subHours(int amount) => addHours(-amount);

  /// Subtracts an amout of days from this [DateTime]
  DateTime subDays(int amount) => addDays(-amount);

  /// Subtracts an amout of milliseconds from this [DateTime]
  DateTime subMilliseconds(int amount) => addMilliseconds(-amount);

  /// Subtracts an amout of microseconds from this [DateTime]
  DateTime subMicroseconds(int amount) => addMicroseconds(-amount);

  // DateTime subISOYears(amount)
  /// Subtracts an amout of minutes from this [DateTime]
  DateTime subMinutes(int amount) => addMinutes(-amount);

  /// Subtracts an amout of months from this [DateTime]
  DateTime subMonths(int amount) => addMonths(-amount);

  // DateTime subQuarters(amount)
  /// Subtracts an amout of seconds from this [DateTime]
  DateTime subSeconds(int amount) => addSeconds(-amount);

  // DateTime subWeeks(amount)
  /// Subtracts an amout of years from this [DateTime]
  DateTime subYears(int amount) => addYears(-amount);

  /// Check if two dates are equal to each other
  ///
  /// Returns true if this [DateTime] represents exactly the same moment in time as [other].
  bool equals(DateTime other) => isAtSameMomentAs(other);

  bool operator <(DateTime other) => isBefore(other);

  bool operator <=(DateTime other) =>
      isBefore(other) || isAtSameMomentAs(other);

  bool operator >(DateTime other) => isAfter(other);

  bool operator >=(DateTime other) => isAfter(other) || isAtSameMomentAs(other);

  String toHumanString() => format('E MMM d y H:m:s');

  /// The day after
  /// The day after this [DateTime]
  DateTime get nextDay => addDays(1);

  /// The day previous this [DateTime]
  DateTime get previousDay => addDays(-1);

  /// The month after this [DateTime]
  DateTime get nextMonth => clone.setMonth(month + 1);

  /// The month previous this [DateTime]
  DateTime get previousMonth => clone.setMonth(month - 1);

  /// The year after this [DateTime]
  DateTime get nextYear => clone.setYear(year + 1);

  /// The year previous this [DateTime]
  DateTime get previousYear => clone.setYear(year - 1);

  /// The week after this [DateTime]
  DateTime get nextWeek => addDays(7);

  /// The week previous this [DateTime]
  DateTime get previousWeek => subDays(7);

  /// Number of seconds since epoch time
  ///
  /// The Unix epoch (or Unix time or POSIX time or Unix timestamp) is the number of
  /// seconds that have elapsed since January 1, 1970 (midnight UTC/GMT), not counting
  /// leap seconds (in ISO 8601: 1970-01-01T00:00:00Z).
  /// Literally speaking the epoch is Unix time 0 (midnight 1/1/1970).
  int get secondsSinceEpoch => millisecondsSinceEpoch ~/ 1000;

  /// Format this [DateTime] following the [String pattern]
  ///
  ///      ICU Name                   Skeleton
  ///      --------                   --------
  ///      DAY                          d
  ///      ABBR_WEEKDAY                 E
  ///      WEEKDAY                      EEEE
  ///      ABBR_STANDALONE_MONTH        LLL
  ///      STANDALONE_MONTH             LLLL
  ///      NUM_MONTH                    M
  ///      NUM_MONTH_DAY                Md
  ///      NUM_MONTH_WEEKDAY_DAY        MEd
  ///      ABBR_MONTH                   MMM
  ///      ABBR_MONTH_DAY               MMMd
  ///      ABBR_MONTH_WEEKDAY_DAY       MMMEd
  ///      MONTH                        MMMM
  ///      MONTH_DAY                    MMMMd
  ///      MONTH_WEEKDAY_DAY            MMMMEEEEd
  ///      ABBR_QUARTER                 QQQ
  ///      QUARTER                      QQQQ
  ///      YEAR                         y
  ///      YEAR_NUM_MONTH               yM
  ///      YEAR_NUM_MONTH_DAY           yMd
  ///      YEAR_NUM_MONTH_WEEKDAY_DAY   yMEd
  ///      YEAR_ABBR_MONTH              yMMM
  ///      YEAR_ABBR_MONTH_DAY          yMMMd
  ///      YEAR_ABBR_MONTH_WEEKDAY_DAY  yMMMEd
  ///      YEAR_MONTH                   yMMMM
  ///      YEAR_MONTH_DAY               yMMMMd
  ///      YEAR_MONTH_WEEKDAY_DAY       yMMMMEEEEd
  ///      YEAR_ABBR_QUARTER            yQQQ
  ///      YEAR_QUARTER                 yQQQQ
  ///      HOUR24                       H
  ///      HOUR24_MINUTE                Hm
  ///      HOUR24_MINUTE_SECOND         Hms
  ///      HOUR                         j
  ///      HOUR_MINUTE                  jm
  ///      HOUR_MINUTE_SECOND           jms
  ///      HOUR_MINUTE_GENERIC_TZ       jmv
  ///      HOUR_MINUTE_TZ               jmz
  ///      HOUR_GENERIC_TZ              jv
  ///      HOUR_TZ                      jz
  ///      MINUTE                       m
  ///      MINUTE_SECOND                ms
  ///      SECOND                       s
  /// Examples Using the US Locale:
  ///
  ///      Pattern                           Result
  ///      ----------------                  -------
  ///      new DateFormat.yMd()             -> 7/10/1996
  ///      new DateFormat('yMd')            -> 7/10/1996
  ///      new DateFormat.yMMMMd('en_US')   -> July 10, 1996
  ///      new DateFormat.jm()              -> 5:08 PM
  ///      new DateFormat.yMd().add_jm()    -> 7/10/1996 5:08 PM
  ///      new DateFormat.Hm()              -> 17:08 // force 24 hour time
  ///
  /// Explicit patterns
  ///
  ///     Symbol   Meaning                Presentation       Example
  ///     ------   -------                ------------       -------
  ///     G        era designator         (Text)             AD
  ///     y        year                   (Number)           1996
  ///     M        month in year          (Text & Number)    July & 07
  ///     L        standalone month       (Text & Number)    July & 07
  ///     d        day in month           (Number)           10
  ///     c        standalone day         (Number)           10
  ///     h        hour in am/pm (1~12)   (Number)           12
  ///     H        hour in day (0~23)     (Number)           0
  ///     m        minute in hour         (Number)           30
  ///     s        second in minute       (Number)           55
  ///     S        fractional second      (Number)           978
  ///     E        day of week            (Text)             Tuesday
  ///     D        day in year            (Number)           189
  ///     a        am/pm marker           (Text)             PM
  ///     k        hour in day (1~24)     (Number)           24
  ///     K        hour in am/pm (0~11)   (Number)           0
  ///     z        time zone              (Text)             Pacific Standard Time
  ///     Z        time zone (RFC 822)    (Number)           -0800
  ///     v        time zone (generic)    (Text)             Pacific Time
  ///     Q        quarter                (Text)             Q3
  ///     '        escape for text        (Delimiter)        'DateTime='
  ///     ''       single quote           (Literal)          'o''clock'
  ///
  String format(String pattern, [String locale = 'en_US']) {
    initializeDateFormatting();
    return DateFormat(pattern, locale).format(this);
  }

  /// Get UTC [DateTime] from this [DateTime]
  DateTime get utc => DateTime.fromMicrosecondsSinceEpoch(
        microsecondsSinceEpoch,
        isUtc: true,
      );

  /// Get Local [DateTime] from this [DateTime]
  DateTime get local => DateTime.fromMicrosecondsSinceEpoch(
        microsecondsSinceEpoch,
        isUtc: false,
      );

  /// Subtract a [Duration] from this [DateTime]
  ///
  /// Returns a new [DateTime] representing the moment that is [other] duration before this [DateTime].
  DateTime operator -(Duration other) {
    return this.subtract(other);
  }

  /// Add a [Duration] to this [DateTime]
  ///
  /// Returns a new [DateTime] representing the moment that is [other] duration after this [DateTime].
  DateTime operator +(Duration other) {
    return add(other);
  }
}

extension DurationExtension on Duration {
  Duration operator -(Duration other) {
    return Duration(microseconds: inMicroseconds - other.inMicroseconds);
  }

  Duration operator +(Duration other) {
    return Duration(microseconds: inMicroseconds + other.inMicroseconds);
  }

  Duration operator *(num other) {
    return Duration(microseconds: (inMicroseconds * other).round());
  }

  Duration operator /(num other) {
    return Duration(microseconds: (inMicroseconds / other).round());
  }
}
