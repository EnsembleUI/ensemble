import 'dart:convert';
import 'dart:core';
import 'dart:async';

import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecommons.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablemath.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablefetch.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecollections.dart';
import 'package:ensemble_ts_interpreter/parser/regex_ext.dart';
import 'package:flutter/cupertino.dart';
import 'package:json_path/json_path.dart';
import 'package:intl/intl.dart';

import 'UserLocale.dart';
import 'invokablepromises.dart';

const String _descriptorKey = r'__ensemble_js_descriptors__';
const String _prototypeKey = r'__ensemble_js_prototype__';
final Expando<Map<dynamic, JSPropertyDescriptor>> _descriptorExpando =
    Expando<Map<dynamic, JSPropertyDescriptor>>('ensembleJsDescriptors');
final Expando<Object> _prototypeExpando =
    Expando<Object>('ensembleJsPrototype');

class _MissingDescriptorValue {
  const _MissingDescriptorValue();
}

class JSArrayHole {
  const JSArrayHole();

  @override
  String toString() => '';
}

const Object _missingDescriptorValue = _MissingDescriptorValue();
const JSArrayHole jsArrayHole = JSArrayHole();

class JSPropertyDescriptor {
  JSPropertyDescriptor({
    dynamic value = _missingDescriptorValue,
    this.get,
    this.set,
    this.writable = true,
    this.enumerable = true,
    this.configurable = true,
    bool? hasWritable,
    bool? hasEnumerable,
    bool? hasConfigurable,
  })  : hasValue = !identical(value, _missingDescriptorValue),
        value = identical(value, _missingDescriptorValue) ? null : value,
        hasWritable = hasWritable ?? true,
        hasEnumerable = hasEnumerable ?? true,
        hasConfigurable = hasConfigurable ?? true;

  dynamic value;
  dynamic get;
  dynamic set;
  bool writable;
  bool enumerable;
  bool configurable;
  bool hasValue;
  bool hasWritable;
  bool hasEnumerable;
  bool hasConfigurable;

  bool get isAccessor => get != null || set != null;

  Map<String, dynamic> toMap() => {
        if (hasValue) 'value': value,
        if (get != null) 'get': get,
        if (set != null) 'set': set,
        'writable': writable,
        'enumerable': enumerable,
        'configurable': configurable,
      };
}

abstract class GlobalContext {
  static RegExp regExp(String regex, String options) {
    RegExp r = RegExp(regex);
    return r;
  }

  static num _toNumber(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value;
    if (value is bool) return value ? 1 : 0;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return 0;
      return num.tryParse(text) ?? double.nan;
    }
    return num.tryParse(value.toString()) ?? double.nan;
  }

  static int _digitValue(int codeUnit) {
    if (codeUnit >= 48 && codeUnit <= 57) return codeUnit - 48;
    if (codeUnit >= 65 && codeUnit <= 90) return codeUnit - 55;
    if (codeUnit >= 97 && codeUnit <= 122) return codeUnit - 87;
    return -1;
  }

  static num parseIntJs(dynamic value, [int? radix]) {
    if (value is int && radix == null) return value;
    var text = value?.toString().trimLeft() ?? '';
    if (text.isEmpty) return double.nan;

    var sign = 1;
    if (text.startsWith('-') || text.startsWith('+')) {
      if (text.startsWith('-')) sign = -1;
      text = text.substring(1);
    }

    var effectiveRadix = radix ?? 0;
    if (effectiveRadix != 0 && (effectiveRadix < 2 || effectiveRadix > 36)) {
      return double.nan;
    }

    if ((effectiveRadix == 0 || effectiveRadix == 16) &&
        (text.startsWith('0x') || text.startsWith('0X'))) {
      effectiveRadix = 16;
      text = text.substring(2);
    }
    if (effectiveRadix == 0) effectiveRadix = 10;

    var result = 0;
    var consumed = false;
    for (var i = 0; i < text.length; i++) {
      final digit = _digitValue(text.codeUnitAt(i));
      if (digit < 0 || digit >= effectiveRadix) break;
      consumed = true;
      result = result * effectiveRadix + digit;
    }
    return consumed ? result * sign : double.nan;
  }

  static num parseFloatJs(dynamic value) {
    final text = value?.toString().trimLeft() ?? '';
    if (text.startsWith('Infinity')) return double.infinity;
    if (text.startsWith('+Infinity')) return double.infinity;
    if (text.startsWith('-Infinity')) return double.negativeInfinity;

    final match =
        RegExp(r'^[+-]?(?:(?:\d+\.\d*)|(?:\.\d+)|(?:\d+))(?:[eE][+-]?\d+)?')
            .firstMatch(text);
    if (match == null) return double.nan;
    return double.tryParse(match.group(0)!) ?? double.nan;
  }

  static Map<String, dynamic> _context = {
    'regExp': regExp,
    'Math': InvokableMath(),
    'parseFloat': parseFloatJs,
    'parseInt': parseIntJs,

    'parseDouble': (dynamic value) {
      if (value is String) {
        return double.tryParse(value) ?? double.nan;
      } else if (value is num) {
        return value.toDouble();
      } else {
        return double.nan;
      }
    },

    'JSON': JSON(),
    'btoa': _String.btoa,
    'atob': _String.atob,
    'console': Console(),
    'Date': StaticDate(),
    'Object': InvokableObject(),
    'Error': JSCustomException(null),
    'Array': StaticArray(),
    'Number': StaticNumber(),
    'String': StaticString(),
    'performance': StaticPerformance(),
    'Map': JSMapConstructor(),
    'Set': JSSetConstructor(),
    'queueMicrotask': (Function cb) => scheduleMicrotask(() {
          try {
            cb([]);
          } catch (_) {}
        }),
    'isNaN': (dynamic value) {
      final number = _toNumber(value);
      return number.isNaN;
    },
    'isFinite': (dynamic value) {
      final number = _toNumber(value);
      return number.isFinite;
    },
    // Encode and Decode URI Component functions
    'encodeURIComponent': (String s) => Uri.encodeComponent(s),
    'decodeURIComponent': (String s) => Uri.decodeComponent(s),
    // Encode and Decode URI functions
    'encodeURI': (String uri) => Uri.encodeFull(uri),
    'decodeURI': (String uri) => Uri.decodeFull(uri),
    'setTimeout': TimerManager.setTimeout,
    'clearTimeout': TimerManager.clearTimeout,
    'setInterval': TimerManager.setInterval,
    'clearInterval': TimerManager.clearInterval,
    'setImmediate': TimerManager.setImmediate,
    'clearImmediate': TimerManager.clearImmediate,
    'Promise': JSPromiseConstructor(),
    'fetch': Fetch.fetch,
  };

  static get context => _context;
}

class InvokableController {
  // remember the last locale set to be used with locale-specific operations
  static Locale? locale;
  static void updateLocale(Map<String, dynamic> dataContext) {
    if (dataContext["app"] is Invokable) {
      var localFunc = (dataContext["app"] as Invokable).getters()["locale"];
      if (localFunc is Function) {
        var foundLocale = localFunc();
        if (foundLocale is UserLocale) {
          locale = foundLocale.toLocale();
          return;
        }
      }
    }
    // if locale is not set, we should clear it out vs using the stale one
    locale = null;
  }

  static bool isPrimitive(dynamic val) {
    bool rtn = val == null;
    if (!rtn) {
      rtn = val is String || val is num || val is bool; //add more
    }
    return rtn;
  }

  static bool isNative(dynamic val) {
    bool rtn = isPrimitive(val);
    if (!rtn) {
      rtn = val is Map || val is List || val is RegExp;
    }
    return rtn;
  }

//   // Sample function to simulate a changing condition
//   static bool isConditionMet() {
//     // Replace this with your actual condition-checking code
//     return DateTime.now().second % 10 == 0;
//   }
//
// // Function to wait until the condition is met
//   static Future<void> waitForCondition() async {
//     while (!isConditionMet()) {
//       print('Condition not met, waiting 500ms...');
//       await Future.delayed(Duration(milliseconds: 500));
//     }
//     print('Condition met! Continuing execution...');
//   }
  static void addGlobals(Map<String, dynamic> context) {
    context.addAll(GlobalContext.context);
    context['globalThis'] = context;
    // context['debug'] = () async {
    //   await waitForCondition();
    // };
  }

  static Map<dynamic, JSPropertyDescriptor> _descriptors(Map map) {
    final existing = _descriptorExpando[map];
    if (existing != null) {
      return existing;
    }
    final descriptors = <dynamic, JSPropertyDescriptor>{};
    _descriptorExpando[map] = descriptors;
    return descriptors;
  }

  static bool isHiddenKey(dynamic key) =>
      key == _descriptorKey || key == _prototypeKey;

  static dynamic _normalizeProperty(dynamic prop) {
    if (prop is num && prop == prop.truncateToDouble()) {
      return prop.toInt();
    }
    return prop;
  }

  static dynamic _normalizeIndexProperty(dynamic prop) {
    prop = _normalizeProperty(prop);
    if (prop is String && RegExp(r'^(0|[1-9]\d*)$').hasMatch(prop)) {
      return int.tryParse(prop) ?? prop;
    }
    return prop;
  }

  static bool isArrayHole(dynamic value) => identical(value, jsArrayHole);

  static void defineProperty(
      dynamic value, dynamic key, JSPropertyDescriptor descriptor) {
    if (value is! Map) {
      throw InvalidPropertyException(
          'Object.defineProperty target must be a map/object');
    }
    key = _normalizeProperty(key);
    final descriptors = _descriptors(value);
    final existing = descriptors[key];
    if (existing != null) {
      final merged = JSPropertyDescriptor(
        get: descriptor.get ?? existing.get,
        set: descriptor.set ?? existing.set,
        writable:
            descriptor.hasWritable ? descriptor.writable : existing.writable,
        enumerable: descriptor.hasEnumerable
            ? descriptor.enumerable
            : existing.enumerable,
        configurable: descriptor.hasConfigurable
            ? descriptor.configurable
            : existing.configurable,
        hasWritable: true,
        hasEnumerable: true,
        hasConfigurable: true,
      );
      if (descriptor.hasValue || existing.hasValue) {
        merged.value = descriptor.hasValue ? descriptor.value : existing.value;
        merged.hasValue = true;
      }
      descriptor = merged;
    }
    descriptors[key] = descriptor;
    if (!descriptor.isAccessor) {
      value[key] = descriptor.value;
    }
  }

  static JSPropertyDescriptor? getOwnPropertyDescriptor(
      dynamic value, dynamic key) {
    if (value is! Map) return null;
    key = _normalizeProperty(key);
    return _descriptors(value)[key];
  }

  static void setPrototype(dynamic value, dynamic prototype) {
    if (value is Map && prototype is Object) {
      _prototypeExpando[value] = prototype;
    }
  }

  static dynamic getPrototype(dynamic value) {
    if (value is Map) {
      return _prototypeExpando[value];
    }
    return null;
  }

  static bool isPrototypeInChain(dynamic value, dynamic prototype) {
    dynamic cursor = value;
    while (cursor is Map) {
      cursor = _prototypeExpando[cursor];
      if (identical(cursor, prototype)) return true;
    }
    return false;
  }

  static List<dynamic> ownEnumerableKeys(Map map) {
    return ownPropertyKeys(map).where((key) {
      if (isHiddenKey(key)) return false;
      final descriptor = getOwnPropertyDescriptor(map, key);
      return descriptor?.enumerable ?? true;
    }).toList();
  }

  static List<dynamic> ownPropertyKeys(Map map) {
    final keys = <dynamic>[
      ...map.keys,
      ..._descriptors(map).keys,
    ];
    return keys.where((key) => !isHiddenKey(key)).toSet().toList();
  }

  static List<dynamic> enumerableKeys(Map map) {
    final keys = <dynamic>[];
    dynamic cursor = map;
    while (cursor is Map) {
      keys.addAll(ownEnumerableKeys(cursor));
      cursor = getPrototype(cursor);
    }
    return keys.toSet().toList();
  }

  static bool hasOwnProperty(dynamic value, dynamic key) {
    key = _normalizeProperty(key);
    if (value is Map) {
      return value.containsKey(key) ||
          getOwnPropertyDescriptor(value, key) != null;
    }
    if (value is List) {
      key = _normalizeIndexProperty(key);
      if (key is int) {
        return key >= 0 && key < value.length && !isArrayHole(value[key]);
      }
    }
    return false;
  }

  static bool propertyIsEnumerable(dynamic value, dynamic key) {
    key = _normalizeProperty(key);
    if (value is Map) {
      if (!hasOwnProperty(value, key)) return false;
      return getOwnPropertyDescriptor(value, key)?.enumerable ?? true;
    }
    if (value is List) {
      key = _normalizeIndexProperty(key);
      return key is int &&
          key >= 0 &&
          key < value.length &&
          !isArrayHole(value[key]);
    }
    return false;
  }

  static bool hasProperty(dynamic value, dynamic key) {
    key = _normalizeProperty(key);
    if (value is Map) {
      if (value.containsKey(key) ||
          getOwnPropertyDescriptor(value, key) != null) {
        return true;
      }
      final prototype = getPrototype(value);
      return prototype != null && hasProperty(prototype, key);
    }
    if (value is List) {
      key = _normalizeIndexProperty(key);
      if (key is int) {
        return key >= 0 && key < value.length && !isArrayHole(value[key]);
      }
      return getters(value).containsKey(key) || methods(value).containsKey(key);
    }
    if (value is String) {
      key = _normalizeIndexProperty(key);
      if (key is int) return key >= 0 && key < value.length;
      return getters(value).containsKey(key) || methods(value).containsKey(key);
    }
    if (value is Invokable) {
      return value.hasGettableProperty(key) || value.hasMethod(key);
    }
    return false;
  }

  static dynamic _callJsFunction(dynamic fn, List<dynamic> args,
      [dynamic thisArg]) {
    if (fn is! Function) {
      try {
        return fn.callWithThis(args, thisArg);
      } on NoSuchMethodError {
        return fn(args);
      }
    }
    try {
      return Function.apply(fn, [args, thisArg]);
    } catch (_) {
      try {
        return Function.apply(fn, [args]);
      } catch (_) {
        return Function.apply(fn, args);
      }
    }
  }

  static Map<String, Function> methods(dynamic val) {
    if (val == null) {
      return {};
    } else if (val is Invokable) {
      return val.methods();
    } else if (val is String) {
      return _String.methods(val);
    } else if (val is bool) {
      return _Boolean.methods(val);
    } else if (val is num) {
      return _Number.methods(val);
    } else if (val is Map) {
      return _Map.methods(val);
    } else if (val is List) {
      return _List.methods(val);
    } else if (val is RegExp) {
      return _RegExp.methods(val);
    }
    return {};
  }

  static Map<String, Function> setters(dynamic val) {
    if (val == null) {
      return {};
    } else if (val is Invokable) {
      return val.setters();
    } else if (val is String) {
      return _String.setters(val);
    } else if (val is bool) {
      return _Boolean.setters(val);
    } else if (val is num) {
      return _Number.setters(val);
    } else if (val is Map) {
      return _Map.setters(val);
    } else if (val is List) {
      return _List.setters(val);
    } else if (val is RegExp) {
      return _RegExp.setters(val);
    }
    return {};
  }

  static Map<String, Function> getters(dynamic val) {
    if (val == null) {
      return {};
    } else if (val is Invokable) {
      return val.getters();
    } else if (val is String) {
      return _String.getters(val);
    } else if (val is bool) {
      return _Boolean.getters(val);
    } else if (val is num) {
      return _Number.getters(val);
    } else if (val is Map) {
      return _Map.getters(val);
    } else if (val is List) {
      return _List.getters(val);
    } else if (val is RegExp) {
      return _RegExp.getters(val);
    }
    return {};
  }

  static dynamic getProperty(dynamic val, dynamic prop) {
    prop = _normalizeProperty(prop);
    if (val == null) {
      throw InvalidPropertyException(
          'Cannot get a property on a null object. Property=$prop');
    } else if (val is Invokable) {
      return val.getProperty(prop);
    } else if (val is String) {
      return _String.getProperty(val, prop);
    } else if (val is bool) {
      return _Boolean.getProperty(val, prop);
    } else if (val is num) {
      return _Number.getProperty(val, prop);
    } else if (val is Map) {
      return _Map.getProperty(val, prop);
    } else if (val is List) {
      return _List.getProperty(val, prop);
    } else if (val is RegExp) {
      return _RegExp.getProperty(val, prop);
    }
    return null;
  }

  static dynamic setProperty(dynamic val, dynamic prop, dynamic value) {
    prop = _normalizeProperty(prop);
    if (val == null) {
      throw InvalidPropertyException(
          'Cannot set a property on a null object. Property=$prop and prop value=$value');
    } else if (val is Invokable) {
      return val.setProperty(prop, value);
    } else if (val is String) {
      return _String.setProperty(val, prop, value);
    } else if (val is bool) {
      return _Boolean.setProperty(val, prop, value);
    } else if (val is num) {
      return _Number.setProperty(val, prop, value);
    } else if (val is Map) {
      return _Map.setProperty(val, prop, value);
    } else if (val is List) {
      return _List.setProperty(val, prop, value);
    } else if (val is RegExp) {
      return _RegExp.setProperty(val, prop, value);
    }
    return {};
  }

  static bool deleteProperty(dynamic val, dynamic prop) {
    prop = _normalizeProperty(prop);
    if (val == null) {
      return false;
    } else if (val is Invokable) {
      // For Invokable objects, try to use deleteProperty if available
      try {
        val.setProperty(prop, null);
        return true;
      } catch (e) {
        return false;
      }
    } else if (val is Map) {
      final descriptor = getOwnPropertyDescriptor(val, prop);
      if (descriptor != null && !descriptor.configurable) return false;
      _descriptors(val).remove(prop);
      return val.remove(prop) != null || descriptor != null;
    } else if (val is List) {
      prop = _normalizeIndexProperty(prop);
      // For lists, delete by index
      if (prop is int && prop >= 0 && prop < val.length) {
        val[prop] = jsArrayHole;
        return true;
      }
      return false;
    }
    // For other types, deletion is not supported
    return false;
  }

  static List<String> getGettableProperties(dynamic obj) {
    if (obj is Invokable) {
      return Invokable.getGettableProperties(obj);
    } else {
      return InvokableController.getters(obj).keys.toList();
    }
  }

  static List<String> getSettableProperties(dynamic obj) {
    if (obj is Invokable) {
      return Invokable.getSettableProperties(obj);
    } else {
      return InvokableController.setters(obj).keys.toList();
    }
  }

  static Map<String, Function> getMethods(dynamic obj) {
    if (obj is Invokable) {
      return Invokable.getMethods(obj);
    } else {
      return InvokableController.methods(obj);
    }
  }
}

class Console extends Object with Invokable, MethodExecutor {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'log': (dynamic args) => _log('log', _normalizeArgs(args)),
      'info': (dynamic args) => _log('info', _normalizeArgs(args)),
      'warn': (dynamic args) => _log('warn', _normalizeArgs(args)),
      'error': (dynamic args) => _log('error', _normalizeArgs(args)),
      'debug': (dynamic args) => _log('debug', _normalizeArgs(args)),
      'trace': (dynamic args) => _trace(_normalizeArgs(args)),
    };
  }

  @override
  Map<String, Function> setters() => {};

  List<dynamic> _normalizeArgs(dynamic args) {
    if (args == null) {
      return [];
    }
    if (args is List<dynamic>) {
      return args;
    }
    return [args];
  }

  String _formatArg(dynamic value) {
    if (value == null) return 'null';
    if (value is bool || value is num) return value.toString();
    if (value is String) return value;
    if (value is RegExp) return value.pattern;
    if (value is DateTime) return value.toIso8601String();

    if (value is Map || value is Iterable) {
      try {
        return jsonEncode(value);
      } catch (_) {
        // Fall through to string conversion if encoding fails
      }
    }

    try {
      return value.toString();
    } catch (_) {
      return '<unprintable>';
    }
  }

  void _emit(String level, List<dynamic> args, {StackTrace? stack}) {
    final formattedArgs = args.map(_formatArg).toList();
    final message = formattedArgs.join(' ');
    final prefix = level == 'log' ? '' : '[console.$level]';
    final buffer = StringBuffer('$prefix$message');
    if (stack != null) {
      buffer.writeln();
      buffer.write(stack.toString());
    }
    debugPrint(buffer.toString());
  }

  dynamic _log(String level, List<dynamic> args) {
    _emit(level, args);
    return null;
  }

  dynamic _trace(List<dynamic> args) {
    _emit('trace', args, stack: StackTrace.current);
    return null;
  }

  @override
  dynamic callMethod(String methodName, List<dynamic> args) {
    switch (methodName) {
      case 'log':
        return _log('log', args);
      case 'info':
        return _log('info', args);
      case 'warn':
        return _log('warn', args);
      case 'error':
        return _log('error', args);
      case 'debug':
        return _log('debug', args);
      case 'trace':
        return _trace(args);
      default:
        throw InvalidPropertyException(
            'console does not have a method named $methodName');
    }
  }
}

class TimerManager {
  static final Map<int, Timer> _timers = {};
  static final Map<int, Timer> _intervals = {};
  static int _nextId = 1;

  static int _toMilliseconds(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) {
      final int? parsedInt = int.tryParse(value);
      if (parsedInt != null) return parsedInt;
      final double? parsedDouble = double.tryParse(value);
      if (parsedDouble != null) return parsedDouble.toInt();
    }
    return 0;
  }

  static void _invokeCallback(dynamic callback, List<dynamic> args) {
    try {
      // Filter out trailing null optional args to avoid arity errors.
      final filteredArgs =
          args.takeWhile((element) => element != null).toList();
      if (callback is Function) {
        // JavascriptFunction._onCall expects a single List argument.
        callback(filteredArgs);
      }
    } catch (_) {
      try {
        // Fallback: attempt positional invocation if the callback expects spread args.
        Function.apply(callback, args);
      } catch (_) {
        // Swallow errors to mimic JS setTimeout behavior.
      }
    }
  }

  static int setTimeout(dynamic callback,
      [dynamic delayMs = 0,
      dynamic arg1,
      dynamic arg2,
      dynamic arg3,
      dynamic arg4]) {
    final int id = _nextId++;
    final int ms = _toMilliseconds(delayMs);
    _timers[id] = Timer(Duration(milliseconds: ms), () {
      _timers.remove(id);
      _invokeCallback(callback, [arg1, arg2, arg3, arg4]);
    });
    return id;
  }

  static void clearTimeout([int? id]) {
    if (id == null) return;
    _timers.remove(id)?.cancel();
  }

  static Map<String, dynamic> setInterval(dynamic callback,
      [dynamic delayMs = 0,
      dynamic arg1,
      dynamic arg2,
      dynamic arg3,
      dynamic arg4]) {
    final int id = _nextId++;
    final int ms = _toMilliseconds(delayMs);
    _intervals[id] = Timer.periodic(Duration(milliseconds: ms), (_) {
      _invokeCallback(callback, [arg1, arg2, arg3, arg4]);
    });
    return {
      'id': id,
      'ref': () => null,
      'unref': () => null,
    };
  }

  static void clearInterval([dynamic handle]) {
    if (handle == null) return;
    int? id;
    if (handle is int) {
      id = handle;
    } else if (handle is Map && handle['id'] is int) {
      id = handle['id'] as int;
    }
    if (id == null) return;
    _intervals.remove(id)?.cancel();
  }

  static int setImmediate(dynamic callback,
      [dynamic arg1, dynamic arg2, dynamic arg3, dynamic arg4]) {
    final int id = _nextId++;
    _timers[id] = Timer(Duration.zero, () {
      _timers.remove(id);
      _invokeCallback(callback, [arg1, arg2, arg3, arg4]);
    });
    return id;
  }

  static void clearImmediate([int? id]) {
    if (id == null) return;
    _timers.remove(id)?.cancel();
  }
}

class StaticArray extends Object with Invokable {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'isArray': (dynamic value) => value is List,
    };
  }

  @override
  Map<String, Function> setters() => {};
}

class StaticNumber extends Object with Invokable {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'isNaN': (dynamic value) {
        final num? parsed = num.tryParse(value.toString());
        return parsed != null && parsed.isNaN;
      },
      'isFinite': (dynamic value) {
        final num? parsed = num.tryParse(value.toString());
        return parsed != null && parsed.isFinite;
      },
      'isInteger': (dynamic value) {
        final num? parsed = num.tryParse(value.toString());
        if (parsed == null || parsed.isNaN || !parsed.isFinite) return false;
        return parsed == parsed.truncate();
      }
    };
  }

  @override
  Map<String, Function> setters() => {};
}

class StaticString extends Object with Invokable {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() {
    List<int> _normalizeCodes(dynamic first, List<dynamic> rest) {
      if (first is List) {
        return first.map((e) => int.tryParse(e.toString()) ?? 0).toList();
      }
      List<dynamic> all = [first, ...rest].where((e) => e != null).toList();
      return all.map((e) => int.tryParse(e.toString()) ?? 0).toList();
    }

    return {
      'fromCharCode': (dynamic a,
              [dynamic b, dynamic c, dynamic d, dynamic e, dynamic f]) =>
          String.fromCharCodes(_normalizeCodes(a, [b, c, d, e, f])),
      'fromCodePoint': (dynamic a,
              [dynamic b, dynamic c, dynamic d, dynamic e, dynamic f]) =>
          String.fromCharCodes(_normalizeCodes(a, [b, c, d, e, f])),
    };
  }

  @override
  Map<String, Function> setters() => {};
}

class StaticPerformance extends Object with Invokable {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'now': () => DateTime.now().microsecondsSinceEpoch / 1000,
    };
  }

  @override
  Map<String, Function> setters() => {};
}

class _String {
  //encodes string to base64 string
  static String btoa(String s) {
    final List<int> bytes = utf8.encode(s);
    return base64.encode(bytes);
  }

  //decodes a base64 string
  static String atob(String s) => utf8.decode(base64.decode(s));
  static Map<String, Function> getters(String val) {
    return {'length': () => val.length};
  }

  static dynamic getProperty(String obj, dynamic prop) {
    prop = InvokableController._normalizeIndexProperty(prop);
    if (prop is int && prop >= 0 && prop < obj.length) {
      return obj[prop];
    }
    Function? f = getters(obj)[prop];
    if (f != null) {
      return f();
    }
    throw InvalidPropertyException(
        '$obj does not have a gettable property named $prop');
  }

  static void setProperty(String obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException(
          '$obj does not have a settable property named $prop');
    }
  }

  static String replaceWithJsRegex(
      String input, RegExp regExp, String replacement,
      {bool replaceFirst = false}) {
    // The replace function takes a Match object and returns the replaced string
    String replace(Match match) {
      String result = replacement;

      // Replace all group references in the replacement string
      for (int i = 0; i <= match.groupCount; i++) {
        result = result.replaceAll('\$$i', match.group(i) ?? '');
      }

      return result;
    }

    ;
    // Use replaceFirstMapped if replaceFirst is true, otherwise use replaceAllMapped
    return replaceFirst && !regExp.global
        ? input.replaceFirstMapped(regExp, replace)
        : input.replaceAllMapped(regExp, replace);
  }

  static Map<String, Function> methods(String val) {
    int clampIndex(dynamic index, [int defaultValue = 0]) {
      final parsed = index is num ? index.toInt() : int.tryParse('$index');
      return (parsed ?? defaultValue).clamp(0, val.length);
    }

    return {
      'indexOf': (String str, [int? fromIndex]) {
        if (fromIndex == null) {
          return val.indexOf(str);
        }
        return val.indexOf(str, fromIndex);
      },
      'lastIndexOf': (String str, [start = -1]) =>
          (start == -1) ? val.lastIndexOf(str) : val.lastIndexOf(str, start),
      'charAt': (index) {
        final i = index is num ? index.toInt() : int.tryParse('$index') ?? 0;
        return i >= 0 && i < val.length ? val[i] : '';
      },
      'startsWith': (str) => val.startsWith(str),
      'endsWith': (str) => val.endsWith(str),
      'includes': (str) => val.contains(str),
      'toLowerCase': () => val.toLowerCase(),
      'toUpperCase': () => val.toUpperCase(),
      'trim': () => val.trim(),
      'trimStart': () => val.trimLeft(),
      'trimEnd': () => val.trimRight(),
      'localeCompare': (String str) => val.compareTo(str), //not locale specific
      'repeat': (int count) => val * count,
      'search': (RegExp pattern) =>
          pattern.hasMatch(val) ? pattern.firstMatch(val)?.start : -1,
      'charCodeAt': (int index) =>
          index >= 0 && index < val.length ? val.codeUnitAt(index) : double.nan,
      'codePointAt': (int index) =>
          index >= 0 && index < val.length ? val.codeUnitAt(index) : null,
      'slice': (int start, [int? end]) {
        int adjustedStart = start < 0 ? val.length + start : start;
        adjustedStart = adjustedStart.clamp(0, val.length);
        int adjustedEnd =
            end == null ? val.length : (end < 0 ? val.length + end : end);
        adjustedEnd = adjustedEnd.clamp(adjustedStart, val.length);
        return val.substring(adjustedStart, adjustedEnd);
      },
      'substr': (int start, [int? length]) {
        var adjustedStart = start < 0 ? val.length + start : start;
        adjustedStart = adjustedStart.clamp(0, val.length);
        if (length != null && length <= 0) return '';
        final adjustedEnd = (adjustedStart + (length ?? val.length))
            .clamp(adjustedStart, val.length);
        return val.substring(adjustedStart, adjustedEnd);
      },
      'match': (regexp) {
        RegExp regex = regexp as RegExp;
        final matches = regex.allMatches(val);
        List<String> list = [];
        for (final m in matches) {
          list.add(m[0]!);
        }
        return list;
      },
      'matchAll': (regexp) {
        final matches = (regexp as RegExp).allMatches(val);
        List<String> list = [];
        for (final m in matches) {
          list.add(m[0]!);
        }
        return list;
      },
      'padStart': (n, [str = ' ']) => val.padLeft(n, str),
      'padEnd': (n, [str = ' ']) => val.padRight(n, str),
      'substring': (start, [end = -1]) {
        var adjustedStart = clampIndex(start);
        var adjustedEnd = end == -1 ? val.length : clampIndex(end, val.length);
        if (adjustedStart > adjustedEnd) {
          final tmp = adjustedStart;
          adjustedStart = adjustedEnd;
          adjustedEnd = tmp;
        }
        return val.substring(adjustedStart, adjustedEnd);
      },
      'split': (String delimiter) => val.split(delimiter),
      'prettyCurrency': () => InvokablePrimitive.prettyCurrency(val),
      'prettyDate': () => InvokablePrimitive.prettyDate(val),
      'prettyDateTime': () => InvokablePrimitive.prettyDateTime(val),
      'prettyTime': () => InvokablePrimitive.prettyTime(val),
      'replace': (pattern, replacement) {
        if (pattern is String) {
          return val.replaceFirst(pattern, replacement);
        }
        return replaceWithJsRegex(val, pattern, replacement,
            replaceFirst: true);
      },
      'replaceAll': (pattern, replacement) {
        if (pattern is String) {
          return val.replaceAll(pattern, replacement);
        }
        return replaceWithJsRegex(val, pattern, replacement);
      },
      'replaceAllMapped': (pattern, replacement) =>
          replaceWithJsRegex(val, pattern, replacement),
      'tryParseInt': () => int.tryParse(val),
      'tryParseDouble': () => double.tryParse(val),
      'btoa': () => btoa(val),
      'atob': () => atob(val),
    };
  }

  static Map<String, Function> setters(String val) {
    return {};
  }
}

class _Boolean {
  static Map<String, Function> getters(bool val) {
    return {};
  }

  static Map<String, Function> methods(bool val) {
    return {};
  }

  static Map<String, Function> setters(bool val) {
    return {};
  }

  static dynamic getProperty(bool obj, dynamic prop) {
    Function? f = getters(obj)[prop];
    if (f != null) {
      return f();
    }
    throw InvalidPropertyException(
        '$obj does not have a gettable property named $prop');
  }

  static void setProperty(bool obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException(
          '$obj does not have a settable property named $prop');
    }
  }
}

class _Number {
  static Map<String, Function> getters(num val) {
    return {};
  }

  static Map<String, Function> methods(num val) {
    return {
      'prettyCurrency': () => InvokablePrimitive.prettyCurrency(val),
      'prettyDate': () => InvokablePrimitive.prettyDate(val),
      'prettyDateTime': () => InvokablePrimitive.prettyDateTime(val),
      'prettyDuration': () => InvokablePrimitive.prettyDuration(val),
      'toFixed': (int fractionDigits) => val.toStringAsFixed(fractionDigits),
      'toString': ([int? radix]) {
        if (radix != null) {
          return val.toInt().toRadixString(radix);
        }
        return val.toString();
      },
      'toLocaleString': ([String? locale, dynamic options]) {
        // If called without parameters, use default formatting
        if (locale == null && options == null) {
          try {
            return NumberFormat.decimalPattern().format(val);
          } catch (e) {
            return val.toString();
          }
        }

        String? localeStr;
        if (locale != null) {
          // Handle both hyphen and underscore formats
          List<String> parts = locale.split(RegExp(r'[-_]'));
          if (parts.length > 1) {
            localeStr = '${parts[0]}_${parts[1]}';
          } else {
            localeStr = locale;
          }
        }

        // Handle options if provided
        if (options != null && options is Map) {
          try {
            Map<String, dynamic> optionsMap =
                Map<String, dynamic>.from(options);
            String style = optionsMap['style'] ?? 'decimal';

            switch (style) {
              case 'currency':
                String currencyCode = optionsMap['currency'] ?? 'USD';
                return NumberFormat.currency(
                  locale: localeStr,
                  symbol: currencyCode,
                  decimalDigits: optionsMap['minimumFractionDigits'] ?? 2,
                  customPattern: '#,##0.00',
                  name: currencyCode,
                ).format(val);

              case 'percent':
                return NumberFormat.percentPattern(localeStr).format(val);

              case 'decimal':
              default:
                int? minimumFractionDigits =
                    optionsMap['minimumFractionDigits'];
                int? maximumFractionDigits =
                    optionsMap['maximumFractionDigits'];

                var formatter = NumberFormat.decimalPattern(localeStr);
                if (minimumFractionDigits != null) {
                  formatter.minimumFractionDigits = minimumFractionDigits;
                }
                if (maximumFractionDigits != null) {
                  formatter.maximumFractionDigits = maximumFractionDigits;
                }
                return formatter.format(val);
            }
          } catch (e) {
            // If any error occurs during formatting, return string representation
            return val.toString();
          }
        }

        // Default decimal formatting with locale if provided
        try {
          return NumberFormat.decimalPattern(localeStr).format(val);
        } catch (e) {
          return val.toString();
        }
      }
    };
  }

  static Map<String, Function> setters(num val) {
    return {};
  }

  static dynamic getProperty(num obj, dynamic prop) {
    Function? f = getters(obj)[prop];
    if (f != null) {
      return f();
    }
    throw InvalidPropertyException(
        '$obj does not have a gettable property named $prop');
  }

  static void setProperty(num obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException(
          '$obj does not have a settable property named $prop');
    }
  }
}

class _Map {
  static Map<String, Function> getters(Map map) {
    return {};
  }

  static Map<String, Function> methods(Map map) {
    return {
      'path': (String path, Function? mapFunction) {
        return JsonPath(path)
            .read(map)
            .map((match) => (mapFunction != null)
                ? mapFunction([match.value])
                : match.value)
            .toList();
      },
      'keys': () => InvokableController.ownEnumerableKeys(map),
      'values': () => InvokableController.ownEnumerableKeys(map)
          .map((key) => InvokableController.getProperty(map, key))
          .toList(),
      'entries': () {
        List<Map> list = [];
        for (final key in InvokableController.ownEnumerableKeys(map)) {
          list.add(
              {'key': key, 'value': InvokableController.getProperty(map, key)});
        }
        return list;
      },
      'hasOwnProperty': (dynamic key) =>
          InvokableController.hasOwnProperty(map, key),
      'propertyIsEnumerable': (dynamic key) =>
          InvokableController.propertyIsEnumerable(map, key),
    };
  }

  static Map<String, Function> setters(Map val) {
    return {};
  }

  static dynamic getProperty(Map map, dynamic prop) {
    prop = InvokableController._normalizeProperty(prop);
    final descriptor = InvokableController.getOwnPropertyDescriptor(map, prop);
    if (descriptor != null) {
      if (descriptor.isAccessor) {
        if (descriptor.get == null) return null;
        return InvokableController._callJsFunction(descriptor.get, [], map);
      }
      return descriptor.value;
    }
    if (map.containsKey(prop)) {
      return map[prop];
    }
    final prototype = InvokableController.getPrototype(map);
    if (prototype != null) {
      return InvokableController.getProperty(prototype, prop);
    }
    return null;
  }

  static void setProperty(Map map, dynamic prop, dynamic val) {
    prop = InvokableController._normalizeProperty(prop);
    final descriptor = InvokableController.getOwnPropertyDescriptor(map, prop);
    if (descriptor != null) {
      if (descriptor.isAccessor) {
        if (descriptor.set == null) {
          throw InvalidPropertyException(
              'Object property $prop does not have a setter');
        }
        InvokableController._callJsFunction(descriptor.set, [val], map);
        return;
      }
      if (!descriptor.writable) {
        return;
      }
      descriptor.value = val;
    }
    map[prop] = val;
  }
}

class _List {
  static const int maxPracticalArrayLength = 1000000;
  static const Object _missingSpliceItem = Object();

  static void _checkArrayLength(int targetLength) {
    if (targetLength > maxPracticalArrayLength) {
      throw InvalidPropertyException(
          'Array length $targetLength exceeds the interpreter safety limit of $maxPracticalArrayLength');
    }
  }

  static Map<String, Function> getters(List list) {
    return {'length': () => list.length};
  }

  static Iterable<MapEntry<int, dynamic>> _presentEntries(List list) sync* {
    for (final entry in list.asMap().entries) {
      if (!InvokableController.isArrayHole(entry.value)) {
        yield entry;
      }
    }
  }

  static List _presentValues(List list) =>
      _presentEntries(list).map((entry) => entry.value).toList();

  static dynamic _visibleValue(dynamic value) =>
      InvokableController.isArrayHole(value) ? null : value;

  // ignore: unused_element
  static List filter(List list, Function f) {
    return _presentValues(list).where((e) => f([e])).toList();
  }

  static Map<String, Function> methods(List list) {
    int clampArrayIndex(int value) {
      if (value < 0) return 0;
      if (value > list.length) return list.length;
      return value;
    }

    int normalizeStartIndex(int start) {
      final adjusted = start < 0 ? list.length + start : start;
      return clampArrayIndex(adjusted);
    }

    int normalizeEndIndex(int? end) {
      if (end == null) return list.length;
      final adjusted = end < 0 ? list.length + end : end;
      return clampArrayIndex(adjusted);
    }

    int normalizeFromIndex(int? fromIndex) {
      if (fromIndex == null) return 0;
      return normalizeStartIndex(fromIndex);
    }

    int normalizeLastFromIndex(int? fromIndex) {
      if (list.isEmpty) return -1;
      if (fromIndex == null) return list.length - 1;
      final adjusted = fromIndex < 0 ? list.length + fromIndex : fromIndex;
      if (adjusted < 0) return -1;
      if (adjusted >= list.length) return list.length - 1;
      return adjusted;
    }

    return {
      'map': (Function f) {
        final mapped = List<dynamic>.filled(list.length, jsArrayHole);
        for (final entry in _presentEntries(list)) {
          mapped[entry.key] = f([entry.value, entry.key, list]);
        }
        return mapped;
      },
      'filter': (Function f) => _presentEntries(list)
          .where((entry) => f([entry.value, entry.key, list]))
          .map((entry) => entry.value)
          .toList(),
      'forEach': (Function f) {
        for (final entry in _presentEntries(list)) {
          f([entry.value, entry.key, list]);
        }
      },
      'add': (dynamic val) {
        _checkArrayLength(list.length + 1);
        list.add(val);
      },
      'push': (dynamic val) {
        _checkArrayLength(list.length + 1);
        list.add(val);
        return list.length;
      },
      'indexOf': (dynamic searchElement, [int? fromIndex]) {
        final start = normalizeFromIndex(fromIndex);
        for (final entry in _presentEntries(list)) {
          if (entry.key >= start && entry.value == searchElement) {
            return entry.key;
          }
        }
        return -1;
      },
      'lastIndexOf': (dynamic val, [int? fromIndex]) {
        final end = normalizeLastFromIndex(fromIndex);
        var index = -1;
        for (final entry in _presentEntries(list)) {
          if (entry.key <= end && entry.value == val) index = entry.key;
        }
        return index;
      },
      'unique': () => _presentValues(list).toSet().toList(),
      'sort': ([Function? f]) {
        if (f == null) {
          list.sort();
        } else {
          list.sort((a, b) {
            dynamic result = f([a, b]);
            // Convert floating point comparison to integer
            if (result is double) {
              if (result > 0) return 1;
              if (result < 0) return -1;
              return 0;
            }
            return result;
          });
        }
        return list;
      },
      'sortF': ([Function? f]) {
        if (f == null) {
          list.sort();
        } else {
          list.sort((a, b) => f([a, b]));
        }
        return list;
      },
      'at': (int index) {
        final normalized = index < 0 ? list.length + index : index;
        return normalized >= 0 && normalized < list.length
            ? _visibleValue(list[normalized])
            : null;
      },
      'concat': (List arr) => list + arr,
      'find': (Function f) {
        for (final entry in _presentEntries(list)) {
          if (f([entry.value, entry.key, list])) return entry.value;
        }
        return -1;
      },
      'includes': (dynamic v) => _presentValues(list).contains(v),
      'contains': (dynamic v) => _presentValues(list).contains(v),
      'join': ([String str = ',']) => list.join(str),
      'pop': () => (list.isNotEmpty) ? list.removeLast() : null,
      'reduce': (Function f, [dynamic initialValue]) {
        final entries = _presentEntries(list).toList();
        if (initialValue != null) {
          var accumulator = initialValue;
          for (final entry in entries) {
            accumulator = f([accumulator, entry.value, entry.key, list]);
          }
          return accumulator;
        }
        if (entries.isEmpty) {
          throw StateError('Reduce of empty array with no initial value');
        }
        var accumulator = entries.first.value;
        for (final entry in entries.skip(1)) {
          accumulator = f([accumulator, entry.value, entry.key, list]);
        }
        return accumulator;
      },
      'reduceRight': (Function f, [dynamic initialValue]) {
        final entries = _presentEntries(list).toList().reversed;
        if (initialValue != null) {
          var accumulator = initialValue;
          for (final entry in entries) {
            accumulator = f([accumulator, entry.value, entry.key, list]);
          }
          return accumulator;
        }
        final entryList = entries.toList();
        if (entryList.isEmpty) {
          throw StateError('Reduce of empty array with no initial value');
        }
        var accumulator = entryList.first.value;
        for (final entry in entryList.skip(1)) {
          accumulator = f([accumulator, entry.value, entry.key, list]);
        }
        return accumulator;
      },
      'reverse': () {
        final reversed = list.reversed.toList();
        list
          ..clear()
          ..addAll(reversed);
        return list;
      },
      'slice': ([int? start, int? end]) {
        final from = normalizeStartIndex(start ?? 0);
        final to = normalizeEndIndex(end);
        if (to <= from) return [];
        return list.sublist(from, to);
      },
      'shift': () => list.isNotEmpty ? list.removeAt(0) : null,
      'unshift': (dynamic val) {
        _checkArrayLength(list.length + 1);
        list.insert(0, val);
        return list.length;
      },
      'splice': (int start,
          [int? deleteCount,
          dynamic item1 = _missingSpliceItem,
          dynamic item2 = _missingSpliceItem,
          dynamic item3 = _missingSpliceItem,
          dynamic item4 = _missingSpliceItem,
          dynamic item5 = _missingSpliceItem,
          dynamic item6 = _missingSpliceItem,
          dynamic item7 = _missingSpliceItem,
          dynamic item8 = _missingSpliceItem]) {
        final from = normalizeStartIndex(start);
        final maxDeleteCount = list.length - from;
        final actualDeleteCount =
            (deleteCount ?? maxDeleteCount).clamp(0, maxDeleteCount);
        var removedItems = list.sublist(from, from + actualDeleteCount);
        list.removeRange(from, from + actualDeleteCount);
        final rawItems = [
          item1,
          item2,
          item3,
          item4,
          item5,
          item6,
          item7,
          item8,
        ];
        final items = rawItems
            .where((item) => !identical(item, _missingSpliceItem))
            .toList();
        if (items.length == 1 && items.first is List) {
          _checkArrayLength(list.length + (items.first as List).length);
          list.insertAll(from, items.first);
        } else if (items.isNotEmpty) {
          _checkArrayLength(list.length + items.length);
          list.insertAll(from, items);
        }
        return removedItems;
      },
      'some': (Function f) => _presentEntries(list)
          .any((entry) => f([entry.value, entry.key, list])),
      'every': (Function f) => _presentEntries(list)
          .every((entry) => f([entry.value, entry.key, list])),
      'findIndex': (Function f) {
        for (final entry in _presentEntries(list)) {
          if (f([entry.value, entry.key, list])) return entry.key;
        }
        return -1;
      },
      'fill': (dynamic value, [int start = 0, int? end]) {
        final from = normalizeStartIndex(start);
        final to = normalizeEndIndex(end);
        for (int i = from; i < to; i++) {
          list[i] = value;
        }
        return list;
      },
      'flat': ([int depth = 1]) {
        List flatten(List input, int d) {
          if (d == 0) return List.from(input);
          List out = [];
          for (var e in input) {
            if (InvokableController.isArrayHole(e)) continue;
            if (e is List) {
              out.addAll(flatten(e, d - 1));
            } else {
              out.add(e);
            }
          }
          return out;
        }

        return flatten(list, depth);
      },
      'flatMap': (Function f) {
        List out = [];
        for (final entry in _presentEntries(list)) {
          var mapped = f([entry.value, entry.key, list]);
          if (mapped is List) {
            out.addAll(mapped);
          } else {
            out.add(mapped);
          }
        }
        return out;
      },
      'keys': () => List<int>.generate(list.length, (index) => index),
      'values': () => list.map(_visibleValue).toList(),
      'entries': () => list
          .asMap()
          .entries
          .map((e) => {'key': e.key, 'value': _visibleValue(e.value)})
          .toList(),
      'copyWithin': (int target, int start, [int? end]) {
        int len = list.length;
        int to = target < 0 ? len + target : target;
        int from = start < 0 ? len + start : start;
        int finalIndex = end == null ? len : (end < 0 ? len + end : end);
        int count = (finalIndex - from).clamp(0, len - to);
        if (count <= 0) return list;
        List<dynamic> slice = [];
        for (int i = 0; i < count; i++) {
          int src = from + i;
          slice.add(src < len ? _visibleValue(list[src]) : null);
        }
        for (int i = 0; i < count; i++) {
          int dest = to + i;
          if (dest < len) {
            list[dest] = slice[i];
          }
        }
        return list;
      },
    };
  }

  static Map<String, Function> setters(List list) {
    return {};
  }

  static dynamic getProperty(List list, dynamic prop) {
    prop = InvokableController._normalizeIndexProperty(prop);
    if (prop is int) {
      if (prop < 0 || prop >= list.length) return null;
      return _visibleValue(list[prop]);
    }
    Function? f = getters(list)[prop];
    if (f != null) {
      return f();
    }
    throw InvalidPropertyException(
        'List or Array does not have a gettable property named $prop');
  }

  static void setProperty(List list, dynamic prop, dynamic val) {
    prop = InvokableController._normalizeIndexProperty(prop);
    if (prop is int) {
      _checkArrayLength(prop + 1);
      if (prop >= 0 && prop < list.length) {
        list[prop] = val;
      } else if (list.length == prop) {
        list.add(val);
      } else if (prop > list.length) {
        while (list.length < prop) {
          list.add(jsArrayHole);
        }
        list.add(val);
      }
    } else {
      throw InvalidPropertyException(
          'List or Array does not have a settable property named $prop');
    }
  }
}

class _RegExp {
  static Map<String, Function> getters(RegExp val) {
    return {};
  }

  static Map<String, Function> methods(RegExp val) {
    return {
      'test': (String input) => val.hasMatch(input),
      'exec': (String input) {
        final match = val.firstMatch(input);
        if (match == null) return null;
        List<dynamic> groups = [];
        for (int i = 0; i <= match.groupCount; i++) {
          groups.add(match.group(i));
        }
        groups.add({'index': match.start, 'input': input});
        return groups;
      },
    };
  }

  static Map<String, Function> setters(RegExp val) {
    return {};
  }

  static dynamic getProperty(RegExp obj, dynamic prop) {
    Function? f = getters(obj)[prop];
    if (f != null) {
      return f();
    }
    throw InvalidPropertyException(
        'RegExp does not have a gettable property named $prop');
  }

  static void setProperty(RegExp obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException(
          'RegExp does not have a settable property named $prop');
    }
  }
}
