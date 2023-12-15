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
    return Date(d._dateTime.clone);
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
      _dateTime = DateTime.now();
    } else if (arg2 == null) {
      if (arg1 is String) {
        _dateTime = DateTime.parse(arg1);
      } else {
        _dateTime = DateTime.fromMillisecondsSinceEpoch(arg1);
      }
    } else {
      int year = arg1;
      int month = arg2 + 1; // JavaScript months are zero-based
      int day = arg3 != null ? arg3 : 1;
      int hour = arg4 != null ? arg4 : 0;
      int minute = arg5 != null ? arg5 : 0;
      int second = arg6 != null ? arg6 : 0;
      int millisecond = arg7 != null ? arg7 : 0;

      _dateTime = DateTime(year, month, day, hour, minute, second, millisecond);
    }
  }
  late DateTime _dateTime;
  Date(this._dateTime);

  Map<String, Function> getters() {
    return {
      'time': () => _dateTime.millisecondsSinceEpoch,
      'year': () => _dateTime.year,
      'month': () => _dateTime.month - 1, // JavaScript months are zero-based
      'day': () => _dateTime.day,
      'weekday': () => _dateTime.weekday % 7, // JavaScript days are zero-based
      'hour': () => _dateTime.hour,
      'minute': () => _dateTime.minute,
      'second': () => _dateTime.second,
      'millisecond': () => _dateTime.millisecond,
      'timezoneOffset': () => -_dateTime.timeZoneOffset.inMinutes,
      'isoString': () => _dateTime.toUtc().toIso8601String(),
      'localDateString': () => _dateTime.toLocal().toString().split(' ')[0],
      'localTimeString': () => _dateTime.toLocal().toString().split(' ')[1].split('.')[0],
      'localString': () => _dateTime.toLocal().toString().split('.')[0],
      'utcFullYear': () => _dateTime.toUtc().year,
      'utcMonth': () => _dateTime.toUtc().month - 1, // JavaScript months are zero-based
      'utcDate': () => _dateTime.toUtc().day,
      'utcDay': () => _dateTime.toUtc().weekday % 7, // JavaScript days are zero-based
      'utcHours': () => _dateTime.toUtc().hour,
      'utcMinutes': () => _dateTime.toUtc().minute,
      'utcSeconds': () => _dateTime.toUtc().second,
      'utcMilliseconds': () => _dateTime.toUtc().millisecond,
    };
  }
  @override
  String toJson() {
    return _dateTime.toUtc().toIso8601String();
  }
  Map<String, Function> methods() {
    return {
      'getTime': () => _dateTime.millisecondsSinceEpoch,
      'getFullYear': () => _dateTime.year,
      'getMonth': () => _dateTime.month - 1, // JavaScript months are zero-based
      'getDate': () => _dateTime.day,
      'getDay': () => _dateTime.weekday % 7, // JavaScript days are zero-based
      'getHours': () => _dateTime.hour,
      'getMinutes': () => _dateTime.minute,
      'getSeconds': () => _dateTime.second,
      'getMilliseconds': () => _dateTime.millisecond,
      'getTimezoneOffset': () => -_dateTime.timeZoneOffset.inMinutes,
      'toISOString': () => _dateTime.toUtc().toIso8601String(),
      'toLocaleDateString': () => _dateTime.toLocal().toString().split(' ')[0],
      'toLocaleTimeString': () => _dateTime.toLocal().toString().split(' ')[1].split('.')[0],
      'toLocaleString': () => _dateTime.toLocal().toString().split('.')[0],
      'toJSON': () => _dateTime.toUtc().toIso8601String(),
      'getUTCFullYear': () => _dateTime.toUtc().year,
      'getUTCMonth': () => _dateTime.toUtc().month - 1, // JavaScript months are zero-based
      'getUTCDate': () => _dateTime.toUtc().day,
      'getUTCDay': () => _dateTime.toUtc().weekday % 7, // JavaScript days are zero-based
      'getUTCHours': () => _dateTime.toUtc().hour,
      'getUTCMinutes': () => _dateTime.toUtc().minute,
      'getUTCSeconds': () => _dateTime.toUtc().second,
      'getUTCMilliseconds': () => _dateTime.toUtc().millisecond,
      'setFullYear': (int year) {
        _dateTime = DateTime(year, _dateTime.month, _dateTime.day, _dateTime.hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
        },
      'setMonth': (int month) {
        _dateTime = DateTime(_dateTime.year, month + 1, _dateTime.day, _dateTime.hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
        },
      'setDate': (int day) {
        _dateTime = DateTime(_dateTime.year, _dateTime.month, day, _dateTime.hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setHours': (int hour) {
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setMinutes': (int minute) {
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, _dateTime.hour, minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setSeconds': (int second) {
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, _dateTime.hour, _dateTime.minute, second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setMilliseconds': (int millisecond) {
        _dateTime = DateTime(_dateTime.year, _dateTime.month, _dateTime.day, _dateTime.hour, _dateTime.minute, _dateTime.second, millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setUTCFullYear': (int year) {
        _dateTime = DateTime.utc(year, _dateTime.month, _dateTime.day, _dateTime.hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setUTCMonth': (int month) {
        _dateTime = DateTime.utc(_dateTime.year, month + 1, _dateTime.day, _dateTime.hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setUTCDate': (int day) {
        _dateTime = DateTime.utc(_dateTime.year, _dateTime.month, day, _dateTime.hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setUTCHours': (int hour) {
        _dateTime = DateTime.utc(_dateTime.year, _dateTime.month, _dateTime.day, hour, _dateTime.minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setUTCMinutes': (int minute) {
        _dateTime = DateTime.utc(_dateTime.year, _dateTime.month, _dateTime.day, _dateTime.hour, minute, _dateTime.second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setUTCSeconds': (int second) {
        _dateTime = DateTime.utc(_dateTime.year, _dateTime.month, _dateTime.day, _dateTime.hour, _dateTime.minute, second, _dateTime.millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setUTCMilliseconds': (int millisecond) {
        _dateTime = DateTime.utc(_dateTime.year, _dateTime.month, _dateTime.day, _dateTime.hour, _dateTime.minute, _dateTime.second, millisecond);
        return _dateTime.millisecondsSinceEpoch;
      },
      'setTime': (int milliseconds) {
        _dateTime = DateTime.fromMillisecondsSinceEpoch(milliseconds);
        return _dateTime.millisecondsSinceEpoch;
      },
      'valueOf': () => _dateTime.millisecondsSinceEpoch,
      'toString': () => _dateTime.toString()
    };
  }
  Map<String, Function> setters() {
    return {

    };
  }
  @override
  String toString() {
    return _dateTime.toString();
  }

  @override
  runOperation(String operator, dynamic rhs) {
    int left = _dateTime.millisecondsSinceEpoch;
    int right = 0;
    if ( rhs is Date ) {
      right = rhs._dateTime.millisecondsSinceEpoch;
    } else if ( rhs is num ) {
      right = rhs.toInt();
    } else if ( rhs is String ) {
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