import 'package:ensemble/error_handling.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:yaml/yaml.dart';
import 'package:ensemble/framework/action.dart';

class Utils {
  static final GlobalKey<NavigatorState> globalAppKey = GlobalKey<NavigatorState>();
  /// return an Integer if it is, or null if not
  static int? optionalInt(dynamic value) {
    return value is int ? value : null;
  }
  static bool? optionalBool(dynamic value) {
    return value is bool ? value : null;
  }
  /// return anything as a string if exists, or null if not
  static String? optionalString(dynamic value) {
    String? val = value?.toString();
    if ( val != null ) {
      return translate(val, null);
    }
    return val;
  }
  static double? optionalDouble(dynamic value) {
    return
      value is double ? value :
      value is int ? value.toDouble() :
      value is String ? double.tryParse(value) :
      null;
  }

  /// initiator should be an Invokable. We use this to scope *this* variable
  static EnsembleAction? getAction(dynamic payload, {Invokable? initiator}) {
    if (payload is YamlMap) {

      Map<String, dynamic>? inputs;
      if (payload['inputs'] is YamlMap) {
        inputs = {};
        (payload['inputs'] as YamlMap).forEach((key, value) {
          inputs![key] = value;
        });
      }

      if (payload['action'] == ActionType.navigateScreen.name) {
        return NavigateScreenAction(
          initiator: initiator,
          screenName: payload['name'],
          inputs: inputs);
      } else if (payload['action'] == ActionType.invokeAPI.name) {
        return InvokeAPIAction(
          initiator: initiator,
          apiName: payload['name'],
          inputs: inputs,
          onResponse: Utils.getAction(payload['onResponse'], initiator: initiator),
          onError: Utils.getAction(payload['onError'], initiator: initiator));
      }
    } else if (payload is String) {
      return ExecuteCodeAction(initiator: initiator, codeBlock: payload);
    }
    return null;
  }

  static String getString(dynamic value, {required String fallback}) {
    String val = value?.toString() ?? fallback;
    return translate(val, null);
  }

  static bool getBool(dynamic value, {required bool fallback}) {
    return value is bool ? value : fallback;
  }

  static int getInt(dynamic value, {required int fallback}) {
    return value is int ? value : fallback;
  }

  static double getDouble(dynamic value, {required double fallback}) {
    return
      value is double ? value :
          value is int ? value.toDouble() :
              value is String ? double.tryParse(value) ?? fallback :
                fallback;
  }

  static List<dynamic>? getList(dynamic value) {
    if (value is YamlList) {
      List<dynamic> results = [];
      for (var item in value) {
        results.add(item);
      }
      return results;
    }
    return null;
  }

  static Color? getColor(dynamic value) {
    if (value is String) {
      switch(value) {
        case '.transparent':
        case 'transparent':
          return Colors.transparent;
        case 'black':
          return Colors.black;
        case 'blue':
          return Colors.blue;
        case 'white':
          return Colors.white;
        case 'red':
          return Colors.red;
        case 'grey':
          return Colors.grey;
        case 'teal':
          return Colors.teal;
        case 'amber':
          return Colors.amber;
        case 'pink':
          return Colors.pink;
        case 'purple':
          return Colors.purple;
        case 'yellow':
          return Colors.yellow;
        case 'green':
          return Colors.green;
        case 'brown':
          return Colors.brown;
        case 'cyan':
          return Colors.cyan;
        case 'indigo':
          return Colors.indigo;
        case 'lime':
          return Colors.lime;
        case 'orange':
          return Colors.orange;
      }
    } else if (value is int) {
      return Color(value);
    }
    return null;
  }

  /// return the padding/margin value
  static EdgeInsets getInsets(dynamic value, {EdgeInsets? fallback}) {
    return optionalInsets(value) ?? fallback ?? const EdgeInsets.all(0);
  }
  static EdgeInsets? optionalInsets(dynamic value) {
    if (value is int && value >= 0) {
      return EdgeInsets.all(value.toDouble());
    } else if (value is String) {
      List<String> values = value.split(' ');
      if (values.isEmpty || values.length > 4) {
        throw LanguageError("shorthand notion top/right/bottom/left requires 1 to 4 integers");
      }
      double top = (parseIntFromString(values[0]) ?? 0).toDouble(),
          right = 0,
          bottom = 0,
          left = 0;
      if (values.length == 4) {
        right = (parseIntFromString(values[1]) ?? 0).toDouble();
        bottom = (parseIntFromString(values[2]) ?? 0).toDouble();
        left = (parseIntFromString(values[3]) ?? 0).toDouble();
      } else if (values.length == 3) {
        left = right = (parseIntFromString(values[1]) ?? 0).toDouble();
        bottom = (parseIntFromString(values[2]) ?? 0).toDouble();
      } else if (values.length == 2) {
        left = right = (parseIntFromString(values[1]) ?? 0).toDouble();
        bottom = top;
      }
      return EdgeInsets.only(top: top, right: right, bottom: bottom, left: left);
    }
    return null;
  }

  static int? parseIntFromString(String value) {
    return int.tryParse(value);
  }

  static final onlyExpression = RegExp(r'''^\${([a-z_-\d.:"'\(\)\[\]]+)}$''', caseSensitive: false);
  static final containExpression = RegExp(r'''\${([a-z_-\d.:"'\(\)\[\]]+)}''', caseSensitive: false);
  static final i18nExpression = RegExp(r'r@[a-zA-Z0-9.-_]+',caseSensitive: false);

  //expect r@mystring or r@myapp.myscreen.mystring as long as r@ is there. If r@ is not there, returns the string as-is
  static String translate(String val,BuildContext? ctx) {
    BuildContext? context;
    if ( WidgetsBinding.instance != null ) {
      context = globalAppKey.currentContext;
    }
    context ??= ctx;
    String rtn = val;
    if ( val.trim().isNotEmpty && context != null ) {
      rtn = val.replaceAllMapped(i18nExpression, (match) {
        String str = match.input.substring(match.start,match.end);//get rid of the @
        if ( str.length > 2 ) {
          String _s = str.substring(2);
          try {
            str = FlutterI18n.translate(context!, _s);
          } catch ( e) {//if resource is not defined
            //log it
            debugPrint('unable to get translated string for the '+str+'; exception='+e.toString());
          }
        }
        return str;
      });
    }
    return rtn;
  }
  /// is it $(....)
  static bool isExpression(String expression) {
    return onlyExpression.hasMatch(expression);
  }

  /// contains one or more expression e.g Hello $(firstname) $(lastname)
  static bool hasExpression(String expression) {
    return containExpression.hasMatch(expression);
  }

  /// get the list of expression from the raw string
  /// [input]: Hello $(firstname) $(lastname)
  /// @return [ $(firstname), $(lastname) ]
  static List<String> getExpressionsFromString(String input) {
    return containExpression.allMatches(input)
        .map((e) => e.group(0)!)
        .toList();
  }


}