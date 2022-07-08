import 'package:ensemble/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:yaml/yaml.dart';
import 'package:ensemble/framework/action.dart';

class Utils {
  static final GlobalKey<NavigatorState> globalAppKey = GlobalKey<NavigatorState>();
  /// return an Integer if it is, or null if not
  static int? optionalInt(dynamic value, {int? min, int? max}) {
    int? rtn = value is int ? value : null;
    if (rtn != null && min != null && rtn < min) {
      rtn = null;
    }
    if (rtn != null && max != null && rtn > max) {
      rtn = null;
    }
    return rtn;
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
  static double? optionalDouble(dynamic value, {double? min, double? max}) {
    double? rtn =
      value is double ? value :
      value is int ? value.toDouble() :
      value is String ? double.tryParse(value) :
      null;
    if (rtn != null && min != null && rtn < min) {
      rtn = null;
    }
    if (rtn != null && max != null && rtn > max) {
      rtn = null;
    }
    return rtn;
  }

  /// initiator should be an Invokable. We use this to scope *this* variable
  static EnsembleAction? getAction(dynamic payload, {Invokable? initiator}) {
    if (payload is YamlMap) {

      // timer functionality
      if (payload['options'] is YamlMap) {

      }

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
      } else if (payload['action'] == ActionType.navigateModalScreen.name) {
        return NavigateModalScreenAction(
          initiator: initiator,
          screenName: payload['name'],
          inputs: inputs,
          onModalDismiss: Utils.getAction(payload['onModalDismiss']));
      } else if (payload['action'] == ActionType.invokeAPI.name) {
        return InvokeAPIAction(
          initiator: initiator,
          apiName: payload['name'],
          inputs: inputs,
          onResponse: Utils.getAction(payload['onResponse'], initiator: initiator),
          onError: Utils.getAction(payload['onError'], initiator: initiator));
      } else if (payload['action'] == ActionType.showDialog.name) {
        return ShowDialogAction(
            initiator: initiator,
            content: payload['name'],
            options: getMap(payload['options'])
        );
      } else if (payload['action'] == ActionType.startTimer.name) {
        EnsembleAction? onTimer = Utils.getAction(payload['onTimer'], initiator: initiator);
        if (onTimer == null) {
          throw LanguageError("startTimer requires an Action for 'onTimer'");
        }
        EnsembleAction? onTimerComplete = Utils.getAction(payload['onTimerComplete'], initiator: initiator);

        TimerPayload? timerPayload;
        if (payload['options'] is YamlMap) {
          timerPayload = TimerPayload(
            id: Utils.optionalString(payload['options']['id']),
            startAfter: Utils.optionalInt(payload['options']['startAfter'], min: 0),
            repeat: Utils.getBool(payload['options']['repeat'], fallback: false),
            repeatInterval: Utils.optionalInt(payload['options']['repeatInterval'], min: 1),
            maxTimes: Utils.optionalInt(payload['options']['maxNumberOfTimes'], min: 1)
          );
        }
        if (timerPayload?.repeat == true && timerPayload?.repeatInterval == null) {
          throw LanguageError("Timer's repeatInterval needs a value when repeat is on");
        }

        return StartTimerAction(
          initiator: initiator,
          onTimer: onTimer,
          onTimerComplete: onTimerComplete,
          payload: timerPayload
        );
      } else if (payload['action'] == ActionType.executeCode.name) {
        return ExecuteCodeAction(
            initiator: initiator,
            codeBlock: payload['body'],
            onComplete: Utils.getAction(payload['onComplete'], initiator: initiator)
        );
      }
    }
    /// short-hand //@code string is same as ExecuteCodeAction
    else if (payload is String) {
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

  static int getInt(dynamic value, {required int fallback, int? min, int? max}) {
    return optionalInt(value, min: min, max: max) ?? fallback;
  }

  static double getDouble(dynamic value, {required double fallback, double? min, double? max}) {
    return optionalDouble(value, min: min, max: max) ?? fallback;
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

  static Map<String, dynamic>? getMap(dynamic value) {
    if (value is Map) {
      Map<String, dynamic> results = {};
      value.forEach((key, value) {
        results[key.toString()] = value;
      });
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

  static FontWeight? getFontWeight(dynamic value) {
    if (value is String) {
      switch (value) {
        case 'w100':
          return FontWeight.w100;
        case 'w200':
          return FontWeight.w200;
        case 'w300':
        case 'light':
        return FontWeight.w300;
        case 'w400':
        case 'normal':
        return FontWeight.w400;
        case 'w500':
          return FontWeight.w500;
        case 'w600':
          return FontWeight.w600;
        case 'w700':
        case 'bold':
        return FontWeight.w700;
        case 'w800':
          return FontWeight.w800;
        case 'w900':
          return FontWeight.w900;
      }
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

  static final onlyExpression = RegExp(r'''^\${([a-z_-\d\s.:?="'\(\)\[\]]+)}$''', caseSensitive: false);
  static final containExpression = RegExp(r'''\${([a-z_-\d\s.:?="'\(\)\[\]]+)}''', caseSensitive: false);
  static final i18nExpression = RegExp(r'r@[a-zA-Z0-9.-_]+',caseSensitive: false);

  // extract only the AST after the comment and expression e.g //code <expression>\n<AST>
  static final codeAfterComment = RegExp(r'^//@code[^\n]*\n+((.|\n)+)', caseSensitive: false);

  // match an expression and AST e.g //@code <expression>\n<AST> in group1 and group2
  static final expressionAndAst = RegExp(r'^//@code\s+([^\n]+)\s*\n+((.|\n)+)', caseSensitive: false);

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
  static List<String> getExpressionTokens(String input) {
    return containExpression.allMatches(input)
        .map((e) => e.group(0)!)
        .toList();
  }

  /// parse an Expression and AST into a DataExpression object.
  /// There are two variations:
  /// 1. <expression>
  /// 2. //@code <expression>\n<AST>
  static DataExpression? parseDataExpression(String input) {
    // first match //@code <expression>\n<AST> as it is what we have
    RegExpMatch? match = expressionAndAst.firstMatch(input);
    if (match != null) {
      return DataExpression(
        rawExpression: match.group(1)!,
        expressions: getExpressionTokens(match.group(1)!),
        astExpression: match.group(2)!,
      );
    }
    // fallback to match <expression> only. This is if we don't turn on AST
    List<String> tokens = getExpressionTokens(input);
    if (tokens.isNotEmpty) {
      return DataExpression(
        rawExpression: input,
        expressions: tokens);
    }
    return null;
  }


}