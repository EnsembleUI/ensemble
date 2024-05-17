import 'dart:convert';

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:dart_date/dart_date.dart';

class JSON extends Object with Invokable {
  @override
  Map<String, Function> methods() {
    return {
      'stringify': (dynamic value) => (value != null )? json.encode(value) : null,
      'parse': (String value) => json.decode(value)
    };
  }

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}
class StaticDate extends Object with Invokable {
  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'UTC': ([
        dynamic arg1,
        dynamic arg2,
        dynamic arg3,
        dynamic arg4,
        dynamic arg5,
        dynamic arg6,
        dynamic arg7,
      ]) => Date.utc(arg1,arg2,arg3,arg4,arg5,arg6,arg7),

      'init': ([
        dynamic arg1,
        dynamic arg2,
        dynamic arg3,
        dynamic arg4,
        dynamic arg5,
        dynamic arg6,
        dynamic arg7,
      ]) => Date.init(arg1,arg2,arg3,arg4,arg5,arg6,arg7),
      'parse': (String strDate) => Date.init([strDate]),
      'now': () => Date.init([])
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}
class Date extends Object with Invokable, SupportsPrimitiveOperations{
  static Date now() {
    return Date(DateTime.now());
  }
  static Date fromDate(Date d) {
    return Date(d.dateTime.clone);
  }
  static int utc([
        dynamic arg1,
        dynamic arg2,
        dynamic arg3,
        dynamic arg4,
        dynamic arg5,
        dynamic arg6,
        dynamic arg7,
      ]) {
        if (arg1 != null && arg2 != null) {
          int year = arg1;
          int month = arg2 + 1; // JavaScript months are zero-based
          int day = arg3 != null ? arg3 : 1;
          int hour = arg4 != null ? arg4 : 0;
          int minute = arg5 != null ? arg5 : 0;
          int second = arg6 != null ? arg6 : 0;
          int millisecond = arg7 != null ? arg7 : 0;

          return DateTime.utc(year, month, day, hour, minute, second, millisecond).millisecondsSinceEpoch;
        } else {
          throw ArgumentError('At least 2 parameters are required for utc()');
        }
      }

  Date.init([
        dynamic arg1,
        dynamic arg2,
        dynamic arg3,
        dynamic arg4,
        dynamic arg5,
        dynamic arg6,
        dynamic arg7,
      ]) {
    if (arg1 == null) {
      dateTime = DateTime.now();
    } else if (arg2 == null) {
      if (arg1 is String) {
        dateTime = DateTime.parse(arg1);
      } else {
        dateTime = DateTime.fromMillisecondsSinceEpoch(arg1);
      }
    } else {
      int year = arg1;
      int month = arg2 + 1; // JavaScript months are zero-based
      int day = arg3 != null ? arg3 : 1;
      int hour = arg4 != null ? arg4 : 0;
      int minute = arg5 != null ? arg5 : 0;
      int second = arg6 != null ? arg6 : 0;
      int millisecond = arg7 != null ? arg7 : 0;

      dateTime = DateTime(year, month, day, hour, minute, second, millisecond);
    }
  }

  late DateTime dateTime;

  Date(this.dateTime);

  Map<String, Function> getters() {
    return {
      'time': () => dateTime.millisecondsSinceEpoch,
      'year': () => dateTime.year,
      'month': () => dateTime.month - 1, // JavaScript months are zero-based
      'day': () => dateTime.day,
      'weekday': () => dateTime.weekday % 7, // JavaScript days are zero-based
      'hour': () => dateTime.hour,
      'minute': () => dateTime.minute,
      'second': () => dateTime.second,
      'millisecond': () => dateTime.millisecond,
      'timezoneOffset': () => -dateTime.timeZoneOffset.inMinutes,
      'isoString': () => dateTime.toUtc().toIso8601String(),
      'localDateString': () => dateTime.toLocal().toString().split(' ')[0],
      'localTimeString': () =>
          dateTime.toLocal().toString().split(' ')[1].split('.')[0],
      'localString': () => dateTime.toLocal().toString().split('.')[0],
      'utcFullYear': () => dateTime.toUtc().year,
      'utcMonth': () =>
          dateTime.toUtc().month - 1, // JavaScript months are zero-based
      'utcDate': () => dateTime.toUtc().day,
      'utcDay': () =>
          dateTime.toUtc().weekday % 7, // JavaScript days are zero-based
      'utcHours': () => dateTime.toUtc().hour,
      'utcMinutes': () => dateTime.toUtc().minute,
      'utcSeconds': () => dateTime.toUtc().second,
      'utcMilliseconds': () => dateTime.toUtc().millisecond,
    };
  }
  @override
  String toJson() {
    return dateTime.toUtc().toIso8601String();
  }
  Map<String, Function> methods() {
    return {
      'getTime': () => dateTime.millisecondsSinceEpoch,
      'getFullYear': () => dateTime.year,
      'getMonth': () => dateTime.month - 1, // JavaScript months are zero-based
      'getDate': () => dateTime.day,
      'getDay': () => dateTime.weekday % 7, // JavaScript days are zero-based
      'getHours': () => dateTime.hour,
      'getMinutes': () => dateTime.minute,
      'getSeconds': () => dateTime.second,
      'getMilliseconds': () => dateTime.millisecond,
      'getTimezoneOffset': () => -dateTime.timeZoneOffset.inMinutes,
      'toISOString': () => dateTime.toUtc().toIso8601String(),
      'toLocaleDateString': () => dateTime.toLocal().toString().split(' ')[0],
      'toLocaleTimeString': () =>
          dateTime.toLocal().toString().split(' ')[1].split('.')[0],
      'toLocaleString': () => dateTime.toLocal().toString().split('.')[0],
      'toJSON': () => dateTime.toUtc().toIso8601String(),
      'getUTCFullYear': () => dateTime.toUtc().year,
      'getUTCMonth': () =>
          dateTime.toUtc().month - 1, // JavaScript months are zero-based
      'getUTCDate': () => dateTime.toUtc().day,
      'getUTCDay': () =>
          dateTime.toUtc().weekday % 7, // JavaScript days are zero-based
      'getUTCHours': () => dateTime.toUtc().hour,
      'getUTCMinutes': () => dateTime.toUtc().minute,
      'getUTCSeconds': () => dateTime.toUtc().second,
      'getUTCMilliseconds': () => dateTime.toUtc().millisecond,
      'setFullYear': (int year) {
        dateTime = DateTime(year, dateTime.month, dateTime.day, dateTime.hour,
            dateTime.minute, dateTime.second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setMonth': (int month) {
        dateTime = DateTime(
            dateTime.year,
            month + 1,
            dateTime.day,
            dateTime.hour,
            dateTime.minute,
            dateTime.second,
            dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setDate': (int day) {
        dateTime = DateTime(dateTime.year, dateTime.month, day, dateTime.hour,
            dateTime.minute, dateTime.second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setHours': (int hour) {
        dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day, hour,
            dateTime.minute, dateTime.second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setMinutes': (int minute) {
        dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day,
            dateTime.hour, minute, dateTime.second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setSeconds': (int second) {
        dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day,
            dateTime.hour, dateTime.minute, second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setMilliseconds': (int millisecond) {
        dateTime = DateTime(dateTime.year, dateTime.month, dateTime.day,
            dateTime.hour, dateTime.minute, dateTime.second, millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setUTCFullYear': (int year) {
        dateTime = DateTime.utc(
            year,
            dateTime.month,
            dateTime.day,
            dateTime.hour,
            dateTime.minute,
            dateTime.second,
            dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setUTCMonth': (int month) {
        dateTime = DateTime.utc(
            dateTime.year,
            month + 1,
            dateTime.day,
            dateTime.hour,
            dateTime.minute,
            dateTime.second,
            dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setUTCDate': (int day) {
        dateTime = DateTime.utc(
            dateTime.year,
            dateTime.month,
            day,
            dateTime.hour,
            dateTime.minute,
            dateTime.second,
            dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setUTCHours': (int hour) {
        dateTime = DateTime.utc(dateTime.year, dateTime.month, dateTime.day,
            hour, dateTime.minute, dateTime.second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setUTCMinutes': (int minute) {
        dateTime = DateTime.utc(dateTime.year, dateTime.month, dateTime.day,
            dateTime.hour, minute, dateTime.second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setUTCSeconds': (int second) {
        dateTime = DateTime.utc(dateTime.year, dateTime.month, dateTime.day,
            dateTime.hour, dateTime.minute, second, dateTime.millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setUTCMilliseconds': (int millisecond) {
        dateTime = DateTime.utc(dateTime.year, dateTime.month, dateTime.day,
            dateTime.hour, dateTime.minute, dateTime.second, millisecond);
        return dateTime.millisecondsSinceEpoch;
      },
      'setTime': (int milliseconds) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
        return dateTime.millisecondsSinceEpoch;
      },
      'valueOf': () => dateTime.millisecondsSinceEpoch,
      'toString': () => dateTime.toString()
    };
  }
  Map<String, Function> setters() {
    return {

    };
  }
  @override
  String toString() {
    return dateTime.toString();
  }

  @override
  runOperation(String operator, dynamic rhs) {
    int left = dateTime.millisecondsSinceEpoch;
    int right = 0;
    if (rhs is Date) {
      right = rhs.dateTime.millisecondsSinceEpoch;
    } else if (rhs is num) {
      right = rhs.toInt();
    } else if (rhs is String) {
      right = DateTime.parse(rhs).millisecondsSinceEpoch;
    }
    dynamic rtn;
    switch (operator) {
      case '==':
        rtn = left == right;
        break;
      case '!=':
        rtn = left != right;
        break;
      case '<':
        rtn = left < right;
        break;
      case '<=':
        rtn = left <= right;
        break;
      case '>':
        rtn = left > right;
        break;
      case '>=':
        rtn = left >= right;
        break;
      case '-':
        rtn = left - right;
        break;
      case '+':
        rtn = left + right;
        break;
      case '/':
        rtn = left / right;
        break;
      case '*':
        rtn = left * right;
        break;
      case '%':
        rtn = left % right;
        break;
      case '|':
        rtn = left | right;
        break;
      case '^':
        rtn = left ^ right;
        break;
      case '<<':
        rtn = left << right;
        break;
      case '>>':
        rtn = left >> right;
        break;
      case '&':
        rtn = left & right;
        break;
      default:
        throw ArgumentError('Unrecognized operator ${operator}');
    }
    return rtn;
  }

}