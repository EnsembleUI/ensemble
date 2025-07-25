import 'dart:convert';

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_date/ensemble_date.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'invokablecontroller.dart';

class JSON extends Object with Invokable {
  @override
  Map<String, Function> methods() {
    return {
      'stringify': (dynamic value) =>
          (value != null) ? json.encode(value) : null,
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

class StaticObject extends Object with Invokable {
  @override
  Map<String, Function> methods() {
    return {'init': () => {}};
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

class InvokableObject extends Object with Invokable {
  @override
  Map<String, Function> methods() {
    return {
      'init': () => {},
      'keys': (dynamic value) =>
          (value is Map) ? value.keys.toList() : (value == null ? [] : null),
      'values': (dynamic value) =>
          (value is Map) ? value.values.toList() : (value == null ? [] : null),
      'entries': (dynamic value) =>
          (value is Map) ? value.entries.toList() : (value == null ? [] : null),
      'hasOwnProperty': (dynamic value, String key) =>
          (value is Map) ? value.containsKey(key) : false,
      'getPropertyNames': (dynamic value) =>
          (value is Map) ? value.keys.toList() : (value == null ? [] : null),
      'toString': (dynamic value) => value.toString(),
      'toJSON': (dynamic value) => (value is Map || value is List)
          ? jsonEncode(value)
          : jsonEncode({'value': value}),
      'defineProperty': (dynamic value, String key, dynamic property) {
        if (value is Map) {
          value[key] = property;
        }
        return value;
      },
      'deleteProperty': (dynamic value, String key) =>
          (value is Map) ? value.remove(key) : null,
      'has': (dynamic value, String key) =>
          (value is Map) ? value.containsKey(key) : false,
      'isPrototypeOf': (dynamic proto, dynamic value) =>
          value is InvokableObject && proto is InvokableObject
              ? value.runtimeType == proto.runtimeType
              : false,
      'propertyIsEnumerable': (dynamic value, String key) =>
          (value is Map) ? value.keys.contains(key) : false,
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
// Exception class to represent custom JavaScript exceptions
class JSCustomException with Invokable implements Exception  {
  final dynamic value;
  JSCustomException(this.value);

  @override
  Map<String, Function> getters() {
    return {
      'message': () {
        if (value is JSCustomException) {
          return value.value;
        }
        return value;
      }
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'init': ([message]) => JSCustomException(message)
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
  @override
  String toString() {
    return value;
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
      ]) =>
          Date.utc(arg1, arg2, arg3, arg4, arg5, arg6, arg7),
      'init': ([
        dynamic arg1,
        dynamic arg2,
        dynamic arg3,
        dynamic arg4,
        dynamic arg5,
        dynamic arg6,
        dynamic arg7,
      ]) =>
          Date.init(arg1, arg2, arg3, arg4, arg5, arg6, arg7),
      'parse': (String strDate) => Date.init([strDate]),
      'now': () => Date.init([])
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class Date extends Object with Invokable, SupportsPrimitiveOperations {
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

      return DateTime.utc(year, month, day, hour, minute, second, millisecond)
          .millisecondsSinceEpoch;
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
      } else if (arg1 is double) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(arg1.round());
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
      'time': () => dateTime.toLocal().millisecondsSinceEpoch,
      'year': () => dateTime.toLocal().year,
      'month': () => dateTime.toLocal().month - 1, // JavaScript months are zero-based
      'day': () => dateTime.toLocal().day,
      'weekday': () => dateTime.toLocal().weekday % 7, // JavaScript days are zero-based
      'hour': () => dateTime.toLocal().hour,
      'minute': () => dateTime.toLocal().minute,
      'second': () => dateTime.toLocal().second,
      'millisecond': () => dateTime.toLocal().millisecond,
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

  // create the locale from string if specified, otherwise fallback to global InvokableController's locale
  Locale? _getLocale([String? localeStr]) {
    if (localeStr != null) {
      List<String> parts = localeStr.split('_');
      if (parts.length == 2) {
        return Locale(parts[0], parts[1]);
      } else {
        return Locale(localeStr);
      }
    }
    return InvokableController.locale;
  }

  String _toLocaleDateString([String? localeStr, dynamic options]) {
    Locale? myLocale = _getLocale(localeStr);
    if (options != null && options is Map) {
      String pattern = '';

      // Handle year format
      if (options['year'] != null) {
        switch (options['year']) {
          case 'numeric':
            pattern += 'y';
            break;
          case '2-digit':
            pattern += 'yy';
            break;
          default:
            pattern += 'y';
        }
      }

      // Handle month format
      if (options['month'] != null) {
        switch (options['month']) {
          case 'numeric':
            pattern += 'M';
            break;
          case '2-digit':
            pattern += 'MM';
            break;
          case 'short':
            pattern += 'MMM';
            break;
          case 'long':
            pattern += 'MMMM';
            break;
          default:
            pattern += 'M';
        }
      }

      // Handle day format
      if (options['day'] != null) {
        switch (options['day']) {
          case 'numeric':
            pattern += 'd';
            break;
          case '2-digit':
            pattern += 'dd';
            break;
          default:
            pattern += 'd';
        }
      }

      // If no pattern was specified, use default
      if (pattern.isEmpty) {
        pattern = 'yMd';
      }

      return DateFormat(pattern, myLocale?.toString())
          .format(dateTime.toLocal());
    }

    // Default format if no options provided
    return DateFormat.yMd(myLocale?.toString()).format(dateTime.toLocal());
  }

  String _toLocaleTimeString([String? localeStr]) {
    Locale? myLocale = _getLocale(localeStr);
    return DateFormat.jms(myLocale?.toString()).format(dateTime.toLocal());
  }

  String _toLocaleString([String? localeStr]) =>
      "${_toLocaleDateString(localeStr)}, ${_toLocaleTimeString(localeStr)}";

  Map<String, Function> methods() {
    return {
      'getTime': () => dateTime.toLocal().millisecondsSinceEpoch,
      'getFullYear': () => dateTime.toLocal().year,
      'getMonth': () => dateTime.toLocal().month - 1, // JavaScript months are zero-based
      'getDate': () => dateTime.toLocal().day,
      'getDay': () => dateTime.toLocal().weekday % 7, // JavaScript days are zero-based
      'getHours': () => dateTime.toLocal().hour,
      'getMinutes': () => dateTime.toLocal().minute,
      'getSeconds': () => dateTime.toLocal().second,
      'getMilliseconds': () => dateTime.toLocal().millisecond,
      'getTimezoneOffset': () => -dateTime.timeZoneOffset.inMinutes,
      'toISOString': () => dateTime.toUtc().toIso8601String(),
      'toLocaleDateString': _toLocaleDateString,
      'toLocaleTimeString': _toLocaleTimeString,
      'toLocaleString': _toLocaleString,
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
    return {};
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
