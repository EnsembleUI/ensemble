import 'dart:math';

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/model.dart' as ensemble;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:yaml/yaml.dart';
import 'package:ensemble/framework/action.dart';


class Utils {
  /// global appKey to get the context
  static final GlobalKey<NavigatorState> globalAppKey = GlobalKey<NavigatorState>();

  /// some Flutter widgets (TextInput) has no width constraint, so using them inside
  /// Rows will cause layout exception. We'll just artificially cap them at a max width,
  /// such that they'll overflow the UI instead of layout exception
  static const double widgetMaxWidth = 2000;


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
  static BackgroundImage? getBackgroundImage(dynamic value) {
    if (value is Map) {
      if (value['source'] != null) {
        return BackgroundImage(
          value['source'].toString(),
          fit: BoxFit.values.from(value['fit']),
          alignment: getAlignment(value['alignment'])
        );
      }
    }
    // legacy, just a simply URL string
    else if (value is String) {
      return BackgroundImage(value);
    }
    return null;
  }

  static LinearGradient? getBackgroundGradient(dynamic value) {
    if (value is Map) {
      if (value['colors'] is List) {
        List<Color> colors = [];
        for (dynamic colorEntry in value['colors']) {
          Color? color = Utils.getColor(colorEntry);
          if (color != null) {
            colors.add(color);
          }
        }
        // only valid if have at least 2 colors
        if (colors.length >= 2) {
          return LinearGradient(
            colors: colors,
            begin: getAlignment(value['start']) ?? Alignment.centerLeft,
            end: getAlignment(value['end']) ?? Alignment.centerRight
          );
        }
      }
    }
    return null;
  }
  static Alignment? getAlignment(dynamic value) {
    switch (value) {
      case 'topLeft':
        return Alignment.topLeft;
      case 'topCenter':
        return Alignment.topCenter;
      case 'topRight':
        return Alignment.topRight;
      case 'centerLeft':
        return Alignment.centerLeft;
      case 'center':
        return Alignment.center;
      case 'centerRight':
        return Alignment.centerRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomCenter':
        return Alignment.bottomCenter;
      case 'bottomRight':
        return Alignment.bottomRight;
    }
    return null;
  }
  static  WrapAlignment? getWrapAlignment(dynamic value)
  {
    switch (value) {
      case 'center':
        return WrapAlignment.center;
      case 'start':
        return WrapAlignment.start;
      case 'end':
        return WrapAlignment.end;
      case 'spaceAround':
        return WrapAlignment.spaceAround;
      case 'spaceBetween':
        return WrapAlignment.spaceBetween;
      case 'spaceEvenly':
        return WrapAlignment.spaceEvenly;
    }
  }
  static InputValidator? getValidator(dynamic value) {
    if (value is Map) {
      int? minLength = Utils.optionalInt(value['minLength']);
      int? maxLength = Utils.optionalInt(value['maxLength']);
      String? regex = Utils.optionalString(value['regex']);
      String? regexError = Utils.optionalString(value['regexError']);
      if (minLength != null || maxLength != null || regex != null) {
        return InputValidator(minLength: minLength, maxLength: maxLength, regex: regex, regexError: regexError);
      }
    }
    return null;
  }

  static DateTime? getDate(dynamic value) {
    return InvokablePrimitive.parseDateTime(value);
  }

  static TimeOfDay? getTimeOfDay(dynamic value) {
    List<dynamic>? tokens = value?.toString().split(':');
    if (tokens != null && (tokens.length == 2 || tokens.length == 3)) {
      int? hour = optionalInt(int.tryParse(tokens[0]), min: 0, max: 23);
      int? minute = optionalInt(int.tryParse(tokens[1]), min: 0, max: 59);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }

  static String? getUrl(dynamic value) {
    if (value != null) {
      return Uri.tryParse(value.toString())?.toString();
    }
    return null;
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

      Map<String, dynamic>? styles;
      if (payload['styles'] is YamlMap) {
        styles = {};
        (payload['styles'] as YamlMap).forEach((key, value) {
          styles![key] = value;
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
          id: Utils.optionalString(payload['id']),
          onResponse: Utils.getAction(payload['onResponse'], initiator: initiator),
          onError: Utils.getAction(payload['onError'], initiator: initiator));
      } else if (payload['action'] == ActionType.openCamera.name)
        {
          return ShowCameraAction(
            initiator: initiator,
            options: getMap(payload['options']),
          );
        }
      else if (payload['action'] == ActionType.showDialog.name) {
        return ShowDialogAction(
          initiator: initiator,
          content: payload['name'],
          options: getMap(payload['options']),
          inputs: inputs,
          onDialogDismiss: Utils.getAction(payload['onDialogDismiss'])
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
            id: Utils.optionalString(payload['id']),
            startAfter: Utils.optionalInt(payload['options']['startAfter'], min: 0),
            repeat: Utils.getBool(payload['options']['repeat'], fallback: false),
            repeatInterval: Utils.optionalInt(payload['options']['repeatInterval'], min: 1),
            maxTimes: Utils.optionalInt(payload['options']['maxNumberOfTimes'], min: 1),
            isGlobal: Utils.optionalBool(payload['options']['isGlobal'])
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

      } else if (payload['action'] == ActionType.stopTimer.name) {
        String? id = Utils.optionalString(payload['id']);
        if (id != null) {
          return StopTimerAction(id);
        }
      } else if (payload['action'] == ActionType.closeAllDialogs.name) {
        return CloseAllDialogsAction();
      } else if (payload['action'] == ActionType.showToast.name) {
        return ShowToastAction(
          type: ToastType.values.from(payload['options']?['type']) ?? ToastType.info,
          message: Utils.optionalString(payload['options']?['message']),
          body: payload['options']?['body'],
          dismissible: Utils.optionalBool(payload['options']?['dismissible']),
          position: Utils.optionalString(payload['options']?['position']),
          duration: Utils.optionalInt(payload['options']?['duration'], min: 1),
          styles: styles
        );
      } else if (payload['action'] == ActionType.getLocation.name) {
        return GetLocationAction(
          onLocationReceived: Utils.getAction(payload['onLocationReceived']),
          onError: Utils.getAction(payload['onError']),
          recurring: Utils.optionalBool(payload['options']?['recurring']),
          recurringDistanceFilter: Utils.optionalInt(payload['options']?['recurringDistanceFilter'], min: 50)
        );
      } else if (payload['action'] == ActionType.executeCode.name) {
        return ExecuteCodeAction(
            initiator: initiator,
            inputs: inputs,
            codeBlock: payload['body'],
            onComplete: Utils.getAction(payload['onComplete'], initiator: initiator)
        );
      } else if ( payload['action'] == ActionType.openUrl.name ) {
        return OpenUrlAction(
          payload['url'],
          openInExternalApp: Utils.getBool(payload['openInExternalApp'], fallback: false)
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
  static List<String>? getListOfStrings(dynamic value) {
    if (value is YamlList) {
      List<String> results = [];
      for (var item in value) {
        if ( item is String ) {
          results.add(item);
        } else {
          results.add(item.toString());
        }
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

  static IconModel? getIcon(dynamic value) {
    dynamic icon;
    String? fontFamily;

    // short-hand e.g. 'inbox fontAwesome'
    if (value is String) {
      List<dynamic> tokens = value.split(RegExp(r'\s+'));
      if (tokens.isNotEmpty) {
        return IconModel(
          tokens[0],
          library: tokens.length >= 2 ? tokens[1].toString() : null
        );
      }
    }
    // key/value
    else if (value is Map && value['name'] != null) {
      return IconModel(
        value['name'],
        library: Utils.optionalString(value['library']),
        color: Utils.getColor(value['color']),
        size: Utils.optionalInt(value['size'])
      );
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

  static TextStyle? getTextStyle(dynamic textStyle) {
    if (textStyle is YamlMap) {
      String? fontFamily = Utils.optionalString(textStyle['fontFamily']);
      int? fontSize = Utils.optionalInt(textStyle['fontSize'], min: 1, max: 100);
      Color? color = Utils.getColor(textStyle['color']);
      FontWeight? fontWeight = getFontWeight(textStyle['fontWeight']);

      TextDecoration? decoration;
      switch(textStyle['decoration']) {
        case 'underline':
          decoration = TextDecoration.underline;
          break;
        case 'overline':
          decoration = TextDecoration.overline;
          break;
        case 'lineThrough':
          decoration = TextDecoration.lineThrough;
          break;
        case 'none':
          decoration = TextDecoration.none;
          break;
      }

      if (fontSize != null || color != null) {
        return TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize?.toDouble(),
          color: color,
          decoration: decoration,
          fontWeight: fontWeight
        );
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

  static EBorderRadius? getBorderRadius(dynamic value) {
    if (value is int) {
      // optimize, ignore zero border radius as that causes extra processing for clipping
      if (value != 0) {
        return EBorderRadius.all(value);
      }
    } else if (value is String) {
      List<int> numbers = _stringToIntegers(value, min: 0);
      if (numbers.length == 1) {
        return EBorderRadius.all(numbers[0]);
      } else if (numbers.length == 2) {
        return EBorderRadius.two(numbers[0], numbers[1]);
      } else if (numbers.length == 3) {
        return EBorderRadius.three(numbers[0], numbers[1], numbers[2]);
      } else if (numbers.length == 4) {
        return EBorderRadius.only(numbers[0], numbers[1], numbers[2], numbers[3]);
      } else {
        throw LanguageError('borderRadius requires 1 to 4 integers');
      }
    }
    return null;
  }



  static Offset? getOffset(dynamic offset) {
    if (offset is YamlList) {
      List<dynamic> list = offset.toList();
      if (list.length >= 2 && list[0] is int && list[1] is int) {
        return Offset(list[0].toDouble(), list[1].toDouble());
      }
    }
    return null;
  }

  static Map<String, dynamic>? parseYamlMap(dynamic value) {
    Map<String, dynamic>? rtn;
    if (value is YamlMap) {
      rtn = {};
      value.forEach((key, value) {
        rtn![key] = value;
      });
    }
    return rtn;
  }

  /// parse a string and return a list of integers
  static List<int> _stringToIntegers(String value, {int? min}) {
    List<int> rtn = [];

    List<String> values = value.split(' ');
    for (var val in values) {
      int? number = int.tryParse(val);
      if (number != null && (min == null || number >= min)) {
        rtn.add(number);
      }
    }
    return rtn;
  }

  static int? parseIntFromString(String value) {
    return int.tryParse(value);
  }

  static final onlyExpression = RegExp(r'''^\${([a-z_-\d\s.,:?!$@&|<>\+/*|%^="'\(\)\[\]]+)}$''', caseSensitive: false);
  static final containExpression = RegExp(r'''\${([a-z_-\d\s.,:?!$@&|<>\+/*|%^="'\(\)\[\]]+)}''', caseSensitive: false);

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
        String strToAppend = '';
        if ( str.length > 2 ) {
          String _s = str.substring(2);
          if ( _s.endsWith(']') ) {
            _s = _s.substring(0,_s.length-1);
            strToAppend = ']';
          }
          try {
            str = FlutterI18n.translate(context!, _s);
          } catch ( e) {//if resource is not defined
            //log it
            debugPrint('unable to get translated string for the '+str+'; exception='+e.toString());
          }
        }
        return str+strToAppend;
      });
    }
    return rtn;
  }

  // temporary workaround for internal translation so we dont have to duplicate the translation files in all repos
  static String translateWithFallback(String key, String fallback) {
    String output = FlutterI18n.translate(Utils.globalAppKey.currentContext!, key);
    return output != key ? output : fallback;
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

  /// pick a string randomly from the list
  static String randomize(List<String> strings) {
    assert(strings.isNotEmpty);
    if (strings.length > 1) {
      return strings[Random().nextInt(strings.length)];
    }
    return strings[0];
  }

  /// prefix the asset with the root directory (i.e. ensemble/assets/), plus
  /// stripping any unecessary query params (e.g. anything after the first ?)
  static String getLocalAssetFullPath(String asset) {
    return 'ensemble/assets/${stripQueryParamsFromAsset(asset)}';
  }

  /// strip any query params (anything after the first ?) from our assets e.g. my-image?x=abc
  static String stripQueryParamsFromAsset(String asset) {
    // match everything (that is not a question mark) until the optional question mark
    RegExpMatch? match = RegExp('^([^?]*)\\??').firstMatch(asset);
    return match?.group(1) ?? asset;
  }

}