import 'dart:convert';
import 'dart:core';

import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecommons.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablemath.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/cupertino.dart';
import 'package:json_path/json_path.dart';

class InvokableController {
  static bool isPrimitive(dynamic val) {
    bool rtn = val == null;
    if ( !rtn ) {
      rtn = val is String || val is num || val is bool; //add more
    }
    return rtn;
  }
  static bool isNative(dynamic val) {
    bool rtn = isPrimitive(val);
    if ( !rtn ) {
      rtn = val is Map || val is List || val is RegExp;
    }
    return rtn;
  }
  static RegExp regExp(String regex,String options) {
    RegExp r =  RegExp(regex);
    return r;
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
  static void addGlobals(Map<String,dynamic> context) {
    context['regExp']= regExp;
    context['Math'] = InvokableMath();
    context['parseFloat'] = (String s) => double.parse(s);
    context['parseInt'] = (String s,[int? radix]) => int.parse(s,radix:radix);
    context['parseDouble'] = (String s) => double.parse(s);
    context['JSON'] = JSON();
    context['btoa'] = _String.btoa;
    context['atob'] = _String.atob;
    context['console'] = Console();
    context['Date'] = StaticDate();
    // context['debug'] = () async {
    //   await waitForCondition();
    // };
  }
  static Map<String, Function> methods(dynamic val) {
    if ( val == null ) {
      return {};
    } else if ( val is Invokable ) {
      return val.methods();
    } else if ( val is String) {
      return _String.methods(val);
    } else if ( val is bool ) {
      return _Boolean.methods(val);
    } else if ( val is num ) {
      return _Number.methods(val);
    } else if ( val is Map ) {
      return _Map.methods(val);
    } else if ( val is List ) {
      return _List.methods(val);
    } else if ( val is RegExp ) {
      return _RegExp.methods(val);
    }
    return {};
  }
  static Map<String, Function> setters(dynamic val) {
    if ( val == null ) {
      return {};
    } else if ( val is Invokable ) {
      return val.setters();
    } else if ( val is String) {
      return _String.setters(val);
    } else if ( val is bool ) {
      return _Boolean.setters(val);
    } else if ( val is num ) {
      return _Number.setters(val);
    } else if ( val is Map ) {
      return _Map.setters(val);
    } else if ( val is List ) {
      return _List.setters(val);
    } else if ( val is RegExp ) {
      return _RegExp.setters(val);
    }
    return {};
  }
  static Map<String, Function> getters(dynamic val) {
    if ( val == null ) {
      return {};
    } else if ( val is Invokable ) {
      return val.getters();
    } else if ( val is String) {
      return _String.getters(val);
    } else if ( val is bool ) {
      return _Boolean.getters(val);
    } else if ( val is num ) {
      return _Number.getters(val);
    } else if ( val is Map ) {
      return _Map.getters(val);
    } else if ( val is List ) {
      return _List.getters(val);
    } else if ( val is RegExp ) {
      return _RegExp.setters(val);
    }
    return {};
  }
  static dynamic getProperty(dynamic val, dynamic prop) {
    if ( val == null ) {
      throw InvalidPropertyException('Cannot get a property on a null object. Property=$prop');
    } else if ( val is Invokable ) {
      return val.getProperty(prop);
    } else if ( val is String) {
      return _String.getProperty(val, prop);
    } else if ( val is bool ) {
      return _Boolean.getProperty(val, prop);
    } else if ( val is num ) {
      return _Number.getProperty(val, prop);
    } else if ( val is Map ) {
      return _Map.getProperty(val, prop);
    } else if ( val is List ) {
      return _List.getProperty(val, prop);
    } else if ( val is RegExp ) {
      return _RegExp.getProperty(val, prop);
    }
    return null;
  }
  static dynamic setProperty(dynamic val, dynamic prop, dynamic value) {
    if ( val == null ) {
      throw InvalidPropertyException('Cannot set a property on a null object. Property=$prop and prop value=$value');
    } else if ( val is Invokable ) {
      return val.setProperty(prop,value);
    } else if ( val is String) {
      return _String.setProperty(val, prop, value);
    } else if ( val is bool ) {
      return _Boolean.setProperty(val, prop, value);
    } else if ( val is num ) {
      return _Number.setProperty(val, prop, value);
    } else if ( val is Map ) {
      return _Map.setProperty(val, prop, value);
    } else if ( val is List ) {
      return _List.setProperty(val, prop, value);
    } else if ( val is RegExp ) {
      return _RegExp.setProperty(val, prop, value);
    }
    return {};
  }
  static List<String> getGettableProperties(dynamic obj) {
    if ( obj is Invokable ) {
      return Invokable.getGettableProperties(obj);
    } else {
      return InvokableController.getters(obj).keys.toList();
    }
  }
  static List<String> getSettableProperties(dynamic obj) {
    if ( obj is Invokable ) {
      return Invokable.getSettableProperties(obj);
    } else {
      return InvokableController.setters(obj).keys.toList();
    }
  }
  static Map<String, Function> getMethods(dynamic obj) {
    if ( obj is Invokable ) {
      return Invokable.getMethods(obj);
    } else {
      return InvokableController.methods(obj);
    }
  }

}
class Console extends Object with Invokable {
  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'log': (val) => debugPrint(val?.toString())
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

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
    return {
      'length': () => val.length
    };
  }
  static dynamic getProperty(String obj, dynamic prop) {
    Function? f = getters(obj)[prop];
    if ( f != null ) {
      return f();
    }
    throw InvalidPropertyException('$obj does not have a gettable property named $prop');
  }
  static void setProperty(String obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException('$obj does not have a settable property named $prop');
    }
  }
  static Map<String, Function> methods(String val) {
    return {
      'indexOf': (String str) => val.indexOf(str),
      'lastIndexOf': (String str,[start=-1]) => (start == -1)?val.lastIndexOf(str):val.lastIndexOf(str,start),
      'charAt': (index)=> val[index],
      'startsWith': (str) => val.startsWith(str),
      'endsWith': (str) => val.endsWith(str),
      'includes': (str) => val.contains(str),
      'toLowerCase': () => val.toLowerCase(),
      'toUpperCase': () => val.toUpperCase(),
      'match': (regexp) {
        RegExpMatch? match = (regexp as RegExp).firstMatch(val);
        if ( match != null ) {
          return match[0] as String;
        }
        return null;
      },
      'matchAll': (regexp) {
        final matches = (regexp as RegExp).allMatches(val);
        List<String> list = [];
        for ( final m in matches ) {
          list.add(m[0]!);
        }
        return list;
      },
      'padStart': (n,[str=' ']) => val.padLeft(n,str),
      'padEnd': (n,[str=' ']) => val.padRight(n,str),
      'substring': (start,[end=-1]) => (end == -1)?val.substring(start):val.substring(start,end),
      'split': (String delimiter) => val.split(delimiter),
      'prettyCurrency': () => InvokablePrimitive.prettyCurrency(val),
      'prettyDate': () => InvokablePrimitive.prettyDate(val),
      'prettyDateTime': () => InvokablePrimitive.prettyDateTime(val),
      'prettyTime': () => InvokablePrimitive.prettyTime(val),
      'replace': (pattern,replacement) => val.replaceFirst(pattern, replacement),
      'replaceAll': (pattern,replacement) => val.replaceAll(pattern, replacement),

      'tryParseInt':() => int.tryParse(val),
      'tryParseDouble':() => double.tryParse(val),
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
    if ( f != null ) {
      return f();
    }
    throw InvalidPropertyException('$obj does not have a gettable property named $prop');
  }
  static void setProperty(bool obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException('$obj does not have a settable property named $prop');
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
        if ( radix != null ) {
          return val.toInt().toRadixString(radix);
        }
        return val.toString();
      }
    };
  }
  static Map<String, Function> setters(num val) {
    return {};
  }
  static dynamic getProperty(num obj, dynamic prop) {
    Function? f = getters(obj)[prop];
    if ( f != null ) {
      return f();
    }
    throw InvalidPropertyException('$obj does not have a gettable property named $prop');
  }
  static void setProperty(num obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException('$obj does not have a settable property named $prop');
    }
  }
}
class _Map {
  static Map<String, Function> getters(Map map) {
    return { };
  }
  static Map<String, Function> methods(Map map) {
    return {
      'path':(String path,Function? mapFunction) {
        return JsonPath(path)
            .read(map)
            .map((match)=>(mapFunction!=null)?mapFunction([match.value]):match.value)
            .toList();
      },
      'keys': () => map.keys.toList(),
      'values': () => map.values.toList(),
      'entries': () {
        List<Map> list = [];
        map.forEach((key, value) {
          list.add({'key': key, 'value':value});
        });
        return list;
      }


    };
  }
  static Map<String, Function> setters(Map val) {
    return {};
  }
  static dynamic getProperty(Map map, dynamic prop) {
    return map[prop];
  }

  static void setProperty(Map map, dynamic prop, dynamic val) {
    map[prop] = val;
  }
}
class _List {
  static Map<String, Function> getters(List list) {
    return {
      'length':() => list.length
    };
  }
  static List filter(List list,Function f) {
    return list.where((e) => f([e])).toList();
  }
  static Map<String, Function> methods(List list) {
    return {
      'map': (Function f) => list.map((e) => f([e])).toList(),
      'filter': (Function f) => filter(list,f),
      'forEach': (Function f) =>  list.forEach((e) => f([e])),
      'add': (dynamic val) => list.add(val),
      'push': (dynamic val) => list.add(val),
      'indexOf': (dynamic val) => list.indexOf(val),
      'lastIndexOf': (dynamic val) => list.lastIndexOf(val),
      'unique': () => list.toSet().toList(),
      'sort': ([Function? f]) {
        if ( f == null ) {
          list.sort();
        } else {
          list.sort((a,b)=> f([a,b]));
        }
        return list;

      },
      'sortF': ([Function? f]) {
        if ( f == null ) {
          list.sort();
        } else {
          list.sort((a,b)=> f([a,b]));
        }
        return list;
      },
      'at': (int index) => list[index],
      'concat': (List arr) => list + arr,
      'find': (Function f) => list.firstWhere((e) => f([e]),orElse: () => -1),
      'includes': (dynamic v) => list.contains(v),
      'contains': (dynamic v) => list.contains(v),
      'join': ([String str=',']) => list.join(str),
      'pop': () => (list.isNotEmpty)? list.removeLast(): null,
      'reduce': (Function f) =>  list.reduce((value, element) => f([value,element])),
      'reverse': () => list.reversed.toList(),
    };
  }

  static Map<String, Function> setters(List list) {
    return {};
  }

  static dynamic getProperty(List list, dynamic prop) {
    if ( prop is int ) {
      return list[prop];
    }
    Function? f = getters(list)[prop];
    if ( f != null ) {
      return f();
    }
    throw InvalidPropertyException('List or Array does not have a gettable property named $prop');
  }

  static void setProperty(List list, dynamic prop, dynamic val) {
    if ( prop is int ) {
      if ( prop >= 0 && prop < list.length ) {
        list[prop] = val;
      } else if ( list.length == prop ) {
        list.add(val);
      }
    } else {
      throw InvalidPropertyException('List or Array does not have a settable property named $prop');
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
    };
  }

  static Map<String, Function> setters(RegExp val) {
    return {};
  }
  static dynamic getProperty(RegExp obj, dynamic prop) {
    Function? f = getters(obj)[prop];
    if ( f != null ) {
      return f();
    }
    throw InvalidPropertyException('RegExp does not have a gettable property named $prop');
  }
  static void setProperty(RegExp obj, dynamic prop, dynamic val) {
    Function? func = setters(obj)[prop];
    if (func != null) {
      func(val);
    } else {
      throw InvalidPropertyException('RegExp does not have a settable property named $prop');
    }
  }
}