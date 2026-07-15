import 'dart:convert';

import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_date/ensemble_date.dart';

import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';

import 'invokablecontroller.dart';

class JSON extends Object with Invokable {
  @override
  Map<String, Function> methods() {
    return {
      'stringify': (dynamic value, [dynamic replacer, dynamic space]) {
        dynamic replacerFn;
        if (replacer is Function) {
          replacerFn = replacer;
        }

        int? indent;
        if (space is num) indent = space.toInt();
        if (space is String) indent = space.length;

        dynamic applyReplacer(String key, dynamic val) {
          if (replacerFn != null) {
            return replacerFn([key, val]);
          }
          return val;
        }

        final activeObjects = Set<Object>.identity();

        dynamic walk(dynamic key, dynamic val) {
          val = applyReplacer(key.toString(), val);
          if (InvokableController.isArrayHole(val)) {
            return null;
          }
          if (val is Map) {
            if (!activeObjects.add(val)) {
              throw JSException(1, 'Converting circular structure to JSON');
            }
            try {
              Map<String, dynamic> m = {};
              for (final k in InvokableController.ownEnumerableKeys(val)) {
                m[k.toString()] =
                    walk(k.toString(), InvokableController.getProperty(val, k));
              }
              return m;
            } finally {
              activeObjects.remove(val);
            }
          } else if (val is List) {
            if (!activeObjects.add(val)) {
              throw JSException(1, 'Converting circular structure to JSON');
            }
            try {
              return val
                  .asMap()
                  .entries
                  .map((e) => walk(e.key.toString(), e.value))
                  .toList();
            } finally {
              activeObjects.remove(val);
            }
          }
          return val;
        }

        final processed = walk('', value);
        if (indent != null && indent > 0) {
          return const JsonEncoder.withIndent('  ').convert(processed);
        }
        return jsonEncode(processed);
      },
      'parse': (String value, [dynamic reviver]) {
        dynamic parsed = json.decode(value);
        if (reviver is! Function) return parsed;

        dynamic walk(dynamic key, dynamic val) {
          if (val is Map) {
            final Map<String, dynamic> m = {};
            val.forEach((k, v) {
              m[k] = walk(k, v);
            });
            return reviver([key, m]);
          } else if (val is List) {
            final list = val
                .asMap()
                .entries
                .map((e) => walk(e.key.toString(), e.value))
                .toList();
            return reviver([key, list]);
          } else {
            return reviver([key, val]);
          }
        }

        return walk('', parsed);
      }
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
    return {
      'init': () => {},
      'assign': (dynamic target, [dynamic source, dynamic source2]) {
        if (target is! Map) return target;
        for (final sourceValue in [source, source2]) {
          if (sourceValue is Map) {
            for (final key
                in InvokableController.ownEnumerableKeys(sourceValue)) {
              InvokableController.setProperty(target, key,
                  InvokableController.getProperty(sourceValue, key));
            }
          }
        }
        return target;
      },
      'create': (dynamic proto) {
        final Map<String, dynamic> obj = {};
        if (proto != null) {
          InvokableController.setPrototype(obj, proto);
        }
        return obj;
      },
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

class InvokableObject extends Object with Invokable {
  @override
  Map<String, Function> methods() {
    return {
      'init': () => {},
      'keys': (dynamic value) => (value is Map)
          ? InvokableController.ownEnumerableKeys(value)
          : (value == null ? [] : null),
      'values': (dynamic value) => (value is Map)
          ? InvokableController.ownEnumerableKeys(value)
              .map((key) => InvokableController.getProperty(value, key))
              .toList()
          : (value == null ? [] : null),
      'entries': (dynamic value) => (value is Map)
          ? InvokableController.ownEnumerableKeys(value)
              .map((key) => [key, InvokableController.getProperty(value, key)])
              .toList()
          : (value == null ? [] : null),
      'fromEntries': (dynamic entries) {
        final result = <dynamic, dynamic>{};
        List<dynamic> entryList = [];
        if (entries is List) {
          entryList = entries;
        } else if (entries is Invokable) {
          final method = entries.methods()['entries'];
          final value =
              method == null ? null : Function.apply(method, const []);
          if (value is List) entryList = value;
        }
        for (final entry in entryList) {
          if (entry is List && entry.length >= 2) {
            result[entry[0]] = entry[1];
          } else if (entry is Map) {
            final key = entry.containsKey('key') ? entry['key'] : entry[0];
            final value =
                entry.containsKey('value') ? entry['value'] : entry[1];
            result[key] = value;
          }
        }
        return result;
      },
      'create': (dynamic proto) {
        final Map<String, dynamic> obj = {};
        if (proto != null) {
          InvokableController.setPrototype(obj, proto);
        }
        return obj;
      },
      'getPrototypeOf': (dynamic value) =>
          InvokableController.getPrototype(value),
      'hasOwn': (dynamic value, dynamic key) =>
          InvokableController.hasOwnProperty(value, key),
      'hasOwnProperty': (dynamic value, String key) =>
          InvokableController.hasOwnProperty(value, key),
      'getOwnPropertyNames': (dynamic value) => (value is Map)
          ? InvokableController.ownPropertyKeys(value)
          : (value == null ? [] : null),
      'getPropertyNames': (dynamic value) => (value is Map)
          ? InvokableController.ownPropertyKeys(value)
          : (value == null ? [] : null),
      'toString': (dynamic value) => value.toString(),
      'toJSON': (dynamic value) => JSON().methods()['stringify']!(value),
      'defineProperty': (dynamic value, String key, dynamic property) {
        if (value is Map) {
          InvokableController.defineProperty(
              value, key, _descriptorFromMap(property));
        }
        return value;
      },
      'getOwnPropertyDescriptor': (dynamic value, String key) =>
          InvokableController.getOwnPropertyDescriptor(value, key)?.toMap(),
      'deleteProperty': (dynamic value, String key) =>
          InvokableController.deleteProperty(value, key),
      'has': (dynamic value, String key) =>
          InvokableController.hasProperty(value, key),
      'isPrototypeOf': (dynamic proto, dynamic value) =>
          InvokableController.isPrototypeInChain(value, proto),
      'propertyIsEnumerable': (dynamic value, String key) =>
          InvokableController.propertyIsEnumerable(value, key),
      'assign': (dynamic target, [dynamic source, dynamic source2]) {
        if (target is! Map) return target;
        for (final sourceValue in [source, source2]) {
          if (sourceValue is Map) {
            for (final key
                in InvokableController.ownEnumerableKeys(sourceValue)) {
              InvokableController.setProperty(target, key,
                  InvokableController.getProperty(sourceValue, key));
            }
          }
        }
        return target;
      },
    };
  }

  JSPropertyDescriptor _descriptorFromMap(dynamic property) {
    if (property is JSPropertyDescriptor) return property;
    if (property is Map) {
      final descriptor = JSPropertyDescriptor(
        get: property['get'],
        set: property['set'],
        writable: property['writable'] ?? false,
        enumerable: property['enumerable'] ?? false,
        configurable: property['configurable'] ?? false,
        hasWritable: property.containsKey('writable'),
        hasEnumerable: property.containsKey('enumerable'),
        hasConfigurable: property.containsKey('configurable'),
      );
      if (property.containsKey('value')) {
        descriptor.value = property['value'];
        descriptor.hasValue = true;
      }
      return descriptor;
    }
    return JSPropertyDescriptor(value: property);
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
class JSCustomException with Invokable implements Exception {
  final dynamic value;
  final bool
      isErrorObject; // True if created via new Error(), false if wrapping a throw

  JSCustomException(this.value, {this.isErrorObject = false});

  @override
  Map<String, Function> getters() {
    return {
      'message': () {
        if (value is JSCustomException) {
          return value.value;
        }
        return value ?? '';
      }
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'init': ([message]) => JSCustomException(message, isErrorObject: true)
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  @override
  String toString() {
    return value ?? '';
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
      if (arg1 is Date) {
        // Clone the incoming Date instance
        dateTime = DateTime.fromMillisecondsSinceEpoch(
            arg1.dateTime.millisecondsSinceEpoch);
      } else if (arg1 is DateTime) {
        dateTime =
            DateTime.fromMillisecondsSinceEpoch(arg1.millisecondsSinceEpoch);
      } else if (arg1 is String) {
        dateTime = DateTime.parse(arg1);
      } else if (arg1 is num) {
        dateTime = DateTime.fromMillisecondsSinceEpoch(arg1.round());
      } else {
        // Fallback: try to parse anything else via toString
        dateTime = DateTime.parse(arg1.toString());
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
      'month': () =>
          dateTime.toLocal().month - 1, // JavaScript months are zero-based
      'day': () => dateTime.toLocal().day,
      'weekday': () =>
          dateTime.toLocal().weekday % 7, // JavaScript days are zero-based
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
      'getMonth': () =>
          dateTime.toLocal().month - 1, // JavaScript months are zero-based
      'getDate': () => dateTime.toLocal().day,
      'getDay': () =>
          dateTime.toLocal().weekday % 7, // JavaScript days are zero-based
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
