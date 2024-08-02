import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble_ts_interpreter/invokables/UserLocale.dart';
import 'package:path/path.dart' as p;

import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yaml/yaml.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

class Utils {
  /// global appKey to get the context
  static final GlobalKey<NavigatorState> globalAppKey =
      GlobalKey<NavigatorState>();

  /// some Flutter widgets (TextInput) has no width constraint, so using them inside
  /// Rows will cause layout exception. We'll just artificially cap them at a max width,
  /// such that they'll overflow the UI instead of layout exception
  static const double widgetMaxWidth = 2000;

  /// return an Integer if it is, or null if not
  static int? optionalInt(dynamic value, {int? min, int? max}) {
    int? rtn =
        value is int ? value : (value is String ? int.tryParse(value) : null);
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
    if (val != null) {
      return translate(val, null);
    }
    return val;
  }

  static double? optionalDouble(dynamic value, {double? min, double? max}) {
    double? rtn = value is double
        ? value
        : value is int
            ? value.toDouble()
            : value is String
                ? double.tryParse(value)
                : null;
    if (rtn != null && min != null && rtn < min) {
      rtn = null;
    }
    if (rtn != null && max != null && rtn > max) {
      rtn = null;
    }
    return rtn;
  }

  /// expect a value in seconds
  static Duration? getDuration(dynamic value) {
    double? number = optionalDouble(value, min: 0);
    if (number != null) {
      return Duration(milliseconds: (number * 1000).toInt());
    }
    return null;
  }

  /// value in milliseconds
  static Duration? getDurationMs(dynamic value) {
    int? number = optionalInt(value, min: 0);
    return number != null ? Duration(milliseconds: number) : null;
  }

  static BackgroundImage? getBackgroundImage(dynamic value) {
    if (value is Map) {
      if (value['source'] != null) {
        return BackgroundImage(
          value['source'].toString(),
          fit: BoxFit.values.from(value['fit']),
          alignment: getAlignment(value['alignment']),
          fallback: value['fallback'],
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
          if (color == null) {
            throw LanguageError("Invalid color $colorEntry");
          }
          colors.add(color);
        }
        // only valid if have at least 2 colors
        if (colors.length >= 2) {
          List<double>? stops;
          if (value['stops'] is List) {
            for (dynamic stop in value['stops']) {
              double? stopValue = Utils.optionalDouble(stop, min: 0, max: 1.0);
              if (stopValue == null) {
                throw LanguageError(
                    "Gradient's stop has to be a number from 0.0 to 1.0");
              }
              (stops ??= []).add(stopValue);
            }
          }
          if (stops != null && stops.length != colors.length) {
            throw LanguageError(
                "Gradient's number of colors and stops should be the same.");
          }
          return LinearGradient(
              colors: colors,
              stops: stops,
              begin: getAlignment(value['start']) ?? Alignment.centerLeft,
              end: getAlignment(value['end']) ?? Alignment.centerRight);
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

  static TextDirection? getTextDirection(dynamic value) {
    if (value is String) {
      if (value == "leftToRight") {
        return TextDirection.ltr;
      } else if (value == "rightToLeft") {
        return TextDirection.rtl;
      }
    }
    return null;
  }

  static WrapAlignment? getWrapAlignment(dynamic value) {
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
        return InputValidator(
            minLength: minLength,
            maxLength: maxLength,
            regex: regex,
            regexError: regexError);
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

  static bool isUrl(String source) {
    return source.startsWith('https://') || source.startsWith('http://');
  }

  static LocationData? getLatLng(dynamic value) {
    if (value is String) {
      List<String> tokens = value.split(RegExp('\\s+'));
      if (tokens.length == 2) {
        double? lat = double.tryParse(tokens[0]);
        double? lng = double.tryParse(tokens[1]);
        if (lat != null && lng != null) {
          return LocationData(latitude: lat, longitude: lng);
        }
      }
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

  static int getInt(dynamic value,
      {required int fallback, int? min, int? max}) {
    return optionalInt(value, min: min, max: max) ?? fallback;
  }

  static double getDouble(dynamic value,
      {required double fallback, double? min, double? max}) {
    return optionalDouble(value, min: min, max: max) ?? fallback;
  }

  static List<T>? getList<T>(dynamic value) {
    if (value is List) {
      List<T> results = [];
      for (var item in value) {
        if (item is T) {
          results.add(item);
        }
      }
      return results;
    }
    return null;
  }

  static List<String>? getListOfStrings(dynamic value) {
    if (value is YamlList || value is List) {
      List<String> results = [];
      for (var item in value) {
        if (item is String) {
          results.add(item);
        } else {
          results.add(item.toString());
        }
      }
      return results;
    }
    return null;
  }

  static List<YamlMap>? getListOfYamlMap(dynamic value) {
    if (value is YamlList || value is List) {
      List<YamlMap> results = [];
      for (var item in value) {
        if (item is YamlMap) {
          results.add(item);
        } else {
          results.add(getYamlMap(item) ?? YamlMap());
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

  static YamlMap? getYamlMap(dynamic value) {
    Map? map = getMap(value);
    return map != null ? YamlMap.wrap(map) : null;
  }

  static dynamic convertYamlToDart(dynamic yaml) {
    if (yaml is YamlMap) {
      // Convert the YamlMap to a Map<String, dynamic>
      return yaml.map(
          (key, value) => MapEntry(key.toString(), convertYamlToDart(value)));
    } else if (yaml is YamlList) {
      // Convert the YamlList to a List
      return yaml.map((item) => convertYamlToDart(item)).toList();
    } else {
      // Return the value directly if it's not a YamlMap or YamlList
      return yaml;
    }
  }

  //this is semantically different from the methods above as it is doesn't return null when value is not a map
  static dynamic maybeYamlMap(dynamic value) {
    if (value is Map) {
      return YamlMap.wrap(value);
    }
    return value;
  }

  static Color? getColor(dynamic value) {
    if (value is String) {
      value = value.trim();

      // Check for hexadecimal color pattern (with or without alpha). It begins with #
      RegExp hexColor = RegExp(r'^#?([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$');
      if (hexColor.hasMatch(value)) {
        // Remove the '#' if it exists
        String hexValue = value.replaceFirst('#', '');
        // Ensure full opacity if no alpha value is provided
        if (hexValue.length == 6) {
          hexValue = 'FF$hexValue'; // Add full opacity for RGB values
        }
        // else move alpha to the front (Flutter specific)
        else if (hexValue.length == 8) {
          hexValue = "${hexValue.substring(6, 8)}${hexValue.substring(0, 6)}";
        }
        // Convert to an integer and create a Color object
        try {
          return Color(int.parse('0x$hexValue'));
        } catch (e) {
          // Handle or log the error
          print('Failed to convert hex to Color: $e');
          return null;
        }
      } else if (value.startsWith("0x")) {
        try {
          return Color(int.parse(value));
        } catch (e) {
          debugPrint("fail to convert 0x to Color");
          return null;
        }
      }

      // check for name values
      switch (value) {
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
        return IconModel(tokens[0],
            library: tokens.length >= 2 ? tokens[1].toString() : null);
      }
    }
    // key/value
    else if (value is Map && value['name'] != null) {
      return IconModel(value['name'],
          library: Utils.optionalString(value['library']),
          color: Utils.getColor(value['color']),
          size: Utils.optionalInt(value['size']));
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

  static BoxShadowComposite? getBoxShadowComposite(
      ChangeNotifier widgetController, dynamic inputs) {
    if (inputs is Map) {
      return BoxShadowComposite(widgetController, inputs: inputs);
    }
    return null;
  }

  static BoxShadow? getBoxShadow(dynamic inputs) {
    if (inputs is Map) {
      return BoxShadow(
        color: Utils.getColor(inputs['color']) ?? Colors.black,
        offset: Utils.getOffset(inputs['offset']) ?? Offset.zero,
        blurRadius: Utils.getInt(inputs['blur'], fallback: 0).toDouble(),
        spreadRadius: Utils.getInt(inputs['spread'], fallback: 0).toDouble(),
        blurStyle:
            BlurStyle.values.from(inputs['blurStyle']) ?? BlurStyle.normal,
      );
    }
    return null;
  }

  static TextStyleComposite? getTextStyleAsComposite(
      WidgetController widgetController,
      {dynamic style}) {
    if (style is Map && style.isNotEmpty) {
      return TextStyleComposite(
        widgetController,
        textGradient: Utils.getBackgroundGradient(style['gradient']),
        textAlign: style['textAlign'],
        styleWithFontFamily: getTextStyle(style),
      );
    }
    return null;
  }

  static TextStyle? getTextStyle(dynamic style) {
    if (style is Map) {
      TextStyle textStyle =
          getFontFamily(style['fontFamily']) ?? const TextStyle();
      return textStyle.copyWith(
          shadows: [
            Shadow(
              blurRadius: Utils.optionalDouble(style['shadowRadius']) ?? 0.0,
              color: Utils.getColor(style['shadowColor']) ??
                  const Color(0xFF000000),
              offset: Utils.getOffset(style['shadowOffset']) ?? Offset.zero,
            )
          ],
          fontSize: Utils.optionalInt(style['fontSize'], min: 1, max: 1000)
              ?.toDouble(),
          height: Utils.optionalDouble(style['lineHeightMultiple'],
              min: 0.1, max: 10),
          fontWeight: getFontWeight(style['fontWeight']),
          fontStyle: Utils.optionalBool(style['isItalic']) == true
              ? FontStyle.italic
              : FontStyle.normal,
          color: Utils.getColor(style['color']) ??
              ThemeManager().defaultTextColor(),
          backgroundColor: Utils.getColor(style['backgroundColor']),
          decoration: getDecoration(style['decoration']),
          decorationStyle:
              TextDecorationStyle.values.from(style['decorationStyle']),
          overflow: TextOverflow.values.from(style['overflow']),
          letterSpacing: Utils.optionalDouble(style['letterSpacing']),
          wordSpacing: Utils.optionalDouble(style['wordSpacing']));
    } else if (style is String) {}
    return null;
  }

  //fontFamily could either be a string or a map where the key is the language code and the value is the font family name
  static TextStyle? getFontFamily(dynamic name) {
    String? fontFamily;
    // Check if the name is a map with language codes
    if (name is Map) {
      // Retrieve the current language code
      String? languageCode =
          UserLocale.from(Ensemble().getLocale())?.languageCode;
      if (languageCode != null && name.containsKey(languageCode)) {
        fontFamily = name[languageCode]?.toString();
      }

      // If language code is null or not found in the map, use the default font family if specified
      if (fontFamily == null || fontFamily.isEmpty) {
        fontFamily = name['default']?.toString();
      }
    } else if (name is String) {
      // Handle the case where name is a string
      fontFamily = name;
    }
    // If a valid font family is found, apply it
    if (fontFamily != null && fontFamily.trim().isNotEmpty) {
      try {
        return GoogleFonts.getFont(fontFamily.trim());
      } catch (_) {
        return TextStyle(fontFamily: fontFamily);
      }
    }
    // Return null if no valid font family is found
    return null;
  }

  static TextAlign? getTextAlignment(dynamic align) {
    TextAlign? textAlign;
    switch (align) {
      case 'start':
        textAlign = TextAlign.start;
        break;
      case 'end':
        textAlign = TextAlign.end;
        break;
      case 'left':
        textAlign = TextAlign.left;
        break;
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      case 'justify':
        textAlign = TextAlign.justify;
        break;
    }
    return textAlign;
  }

  static Curve? getCurve(String? curveType) {
    Curve? curve;
    switch (curveType) {
      case 'bounceIn':
        curve = Curves.bounceIn;
      case 'bounceInOut':
        curve = Curves.bounceInOut;
      case 'bounceOut':
        curve = Curves.bounceOut;
      case 'decelerate':
        curve = Curves.decelerate;
      case 'ease':
        curve = Curves.ease;
      case 'easeIn':
        curve = Curves.easeIn;
      case 'easeInBack':
        curve = Curves.easeInBack;
      case 'easeInCirc':
        curve = Curves.easeInCirc;
      case 'easeInCubic':
        curve = Curves.easeInCubic;
      case 'easeInExpo':
        curve = Curves.easeInExpo;
      case 'easeInOut':
        curve = Curves.easeInOut;
      case 'easeInOutBack':
        curve = Curves.easeInOutBack;
      case 'easeInOutCirc':
        curve = Curves.easeInOutCirc;
      case 'easeInOutCubic':
        curve = Curves.easeInOutCubic;
      case 'easeInOutCubicEmphasized':
        curve = Curves.easeInOutCubicEmphasized;
      case 'easeInOutExpo':
        curve = Curves.easeInOutExpo;
      case 'easeInOutQuad':
        curve = Curves.easeInOutQuad;
      case 'easeInOutQuart':
        curve = Curves.easeInOutQuart;
      case 'easeInOutQuint':
        curve = Curves.easeInOutQuint;
      case 'easeInOutSine':
        curve = Curves.easeInOutSine;
      case 'easeInQuad':
        curve = Curves.easeInQuad;
      case 'easeInQuart':
        curve = Curves.easeInQuart;
      case 'easeInQuint':
        curve = Curves.easeInQuint;
      case 'easeInSine':
        curve = Curves.easeInSine;
      case 'easeInToLinear':
        curve = Curves.easeInToLinear;
      case 'easeOut':
        curve = Curves.easeOut;
      case 'easeOutBack':
        curve = Curves.easeOutBack;
      case 'easeOutCirc':
        curve = Curves.easeOutCirc;
      case 'easeOutCubic':
        curve = Curves.easeOutCubic;
      case 'easeOutExpo':
        curve = Curves.easeOutExpo;
      case 'easeOutQuad':
        curve = Curves.easeOutQuad;
      case 'easeOutQuart':
        curve = Curves.easeOutQuart;
      case 'easeOutQuint':
        curve = Curves.easeOutQuint;
      case 'easeOutSine':
        curve = Curves.easeOutSine;
      case 'elasticIn':
        curve = Curves.elasticIn;
      case 'elasticInOut':
        curve = Curves.elasticInOut;
      case 'elasticOut':
        curve = Curves.elasticOut;
      case 'fastEaseInToSlowEaseOut':
        curve = Curves.fastEaseInToSlowEaseOut;
      case 'fastLinearToSlowEaseIn':
        curve = Curves.fastLinearToSlowEaseIn;
      case 'linear':
        curve = Curves.linear;
      case 'linearToEaseOut':
        curve = Curves.linearToEaseOut;
      case 'slowMiddle':
        curve = Curves.slowMiddle;
      default:
        curve = null;
    }

    return curve;
  }

  static TextDecoration? getDecoration(dynamic decoration) {
    if (decoration is String) {
      switch (decoration) {
        case 'underline':
          return TextDecoration.underline;
        case 'overline':
          return TextDecoration.overline;
        case 'lineThrough':
          return TextDecoration.lineThrough;
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
        throw LanguageError(
            "shorthand notion top/right/bottom/left requires 1 to 4 integers");
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
      } else {
        left = right = bottom = top;
      }
      return EdgeInsets.only(
          top: top, right: right, bottom: bottom, left: left);
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
      List<int> numbers = stringToIntegers(value, min: 0);
      if (numbers.length == 1) {
        return EBorderRadius.all(numbers[0]);
      } else if (numbers.length == 2) {
        return EBorderRadius.two(numbers[0], numbers[1]);
      } else if (numbers.length == 3) {
        return EBorderRadius.three(numbers[0], numbers[1], numbers[2]);
      } else if (numbers.length == 4) {
        return EBorderRadius.only(
            numbers[0], numbers[1], numbers[2], numbers[3]);
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

  static BlurStyle? getShadowBlurStyle(dynamic style) {
    return BlurStyle.values.from(style);
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
  static List<int> stringToIntegers(String value, {int? min, int? max}) {
    List<int> rtn = [];

    List<String> values = value.split(' ');
    for (var val in values) {
      int? number = int.tryParse(val);
      if (number != null &&
          (min == null || number >= min) &&
          (max == null || number <= max)) {
        rtn.add(number);
      }
    }
    return rtn;
  }

  static int? parseIntFromString(String value) {
    return int.tryParse(value);
  }

  static final onlyExpression =
      RegExp(r'''^\$\{([^}]+)\}$''', caseSensitive: false);

  static final containExpression =
      RegExp(r'''\$\{([^}{]+(?:\{[^}{]*\}[^}{]*)*)\}''', caseSensitive: false);

  static final i18nExpression = RegExp(r'\br@([\w\.]+)', caseSensitive: false);

  // extract only the code after the comment and expression e.g //@code <expression>\n
  static final codeAfterComment =
      RegExp(r'^//@code[^\n]*\n+((.|\n)+)', caseSensitive: false);

  // match an expression and AST e.g //@code <expression>\n<AST> in group1 and group2
  static final expressionAndAst =
      RegExp(r'^//@code\s+([^\n]+)\s*', caseSensitive: false);

  //expect r@mystring or r@myapp.myscreen.mystring as long as r@ is there. If r@ is not there, returns the string as-is
  static String translate(String val, BuildContext? ctx) {
    BuildContext? context;
    if (WidgetsBinding.instance != null) {
      context = globalAppKey.currentContext;
    }
    context ??= ctx;
    String rtn = val;
    String fallbackKey = '____FALLBACK_WHEN_NOT_FOUND____';
    if (val.trim().isNotEmpty && context != null) {
      rtn = val.replaceAllMapped(i18nExpression, (match) {
        String fullMatch =
            match.group(0) ?? ''; // Get the full match including 'r@'
        String _s = match.group(1) ?? ''; // The captured group, excluding 'r@'
        try {
          _s = FlutterI18n.translate(context!, _s, fallbackKey: fallbackKey);
        } catch (e) {
          debugPrint(
              'unable to get translated string for the $_s; exception=$e');
          return fullMatch; // Return the full match as-is in case of an exception
        }
        if (_s == fallbackKey) {
          debugPrint('unable to get translated string for the $_s');
          return fullMatch; // Return the full match as-is in case of an exception
        }
        return _s;
      });
    }
    return rtn;
  }

  // temporary workaround for internal translation so we dont have to duplicate the translation files in all repos
  static String translateWithFallback(String key, String fallback) {
    if (Utils.globalAppKey.currentContext != null) {
      String output =
          FlutterI18n.translate(Utils.globalAppKey.currentContext!, key);
      return output != key ? output : fallback;
    }
    return fallback;
  }

  // explicitly return null if we can't find the translation key
  static String? translateOrNull(String key) {
    String output =
        FlutterI18n.translate(Utils.globalAppKey.currentContext!, key);
    return output != key ? output : null;
  }

  static String stripEndingArrays(String input) {
    RegExpMatch? match = RegExp(r'^(.+?)(?:\[[^\]]*\])+?$').firstMatch(input);
    if (match != null) {
      return match.group(1).toString();
    }
    return input;
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
    return containExpression.allMatches(input).map((e) => e.group(0)!).toList();
  }

  /// parse an Expression and AST into a DataExpression object.
  /// There are two variations:
  /// 1. <expression>
  /// 2. //@code <expression>\n<AST>
  static DataExpression? parseDataExpression(dynamic input) {
    if (input is String) {
      return _parseDataExpressionFromString(input);
    } else if (input is List) {
      List<String> tokens = [];
      for (final inputEntry in input) {
        if (inputEntry is String) {
          DataExpression? dataEntry =
              _parseDataExpressionFromString(inputEntry);
          tokens.addAll(dataEntry?.expressions ?? []);
        }
      }
      if (tokens.isNotEmpty) {
        return DataExpression(rawExpression: input, expressions: tokens);
      }
    } else if (input is Map) {
      // no recursive, just a straight map is good
      List<String> tokens = [];
      input.forEach((_, value) {
        if (value is String) {
          DataExpression? dataEntry = _parseDataExpressionFromString(value);
          tokens.addAll(dataEntry?.expressions ?? []);
        }
      });
      if (tokens.isNotEmpty) {
        return DataExpression(rawExpression: input, expressions: tokens);
      }
    }
    return null;
  }

  static DataExpression? _parseDataExpressionFromString(String input) {
    // first match //@code <expression>\n<AST> as it is what we have
    RegExpMatch? match = expressionAndAst.firstMatch(input);
    if (match != null) {
      return DataExpression(
          rawExpression: match.group(1)!,
          expressions: getExpressionTokens(match.group(1)!));
    }
    // fallback to match <expression> only. This is if we don't turn on AST
    List<String> tokens = getExpressionTokens(input);
    if (tokens.isNotEmpty) {
      return DataExpression(rawExpression: input, expressions: tokens);
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
  /// stripping any unnecessary query params (e.g. anything after the first ?)
  static String getLocalAssetFullPath(String asset) {
    return 'ensemble/assets/${stripQueryParamsFromAsset(asset)}';
  }

  static bool isMemoryPath(String path) {
    if (kIsWeb) {
      return path.contains('blob:');
    } else if (Platform.isWindows) {
      final pattern = RegExp(r'^[a-zA-Z]:[\\\/]');
      return pattern.hasMatch(path) && p.isAbsolute(path);
    } else if (Platform.isAndroid) {
      return path.startsWith('/data/user/0/');
    } else if (Platform.isIOS) {
      return (path.startsWith('/var/mobile/') ||
          path.startsWith('/private/var/mobile'));
    } else if (Platform.isMacOS) {
      return path.startsWith('/Users/');
    } else if (Platform.isLinux) {
      return path.startsWith('/home/');
    }
    return false;
  }

  /// strip any query params (anything after the first ?) from our assets e.g. my-image?x=abc
  static String stripQueryParamsFromAsset(String asset) {
    // match everything (that is not a question mark) until the optional question mark
    RegExpMatch? match = RegExp('^([^?]*)\\??').firstMatch(asset);
    return match?.group(1) ?? asset;
  }

  static String evaluate(String data, Map<String, dynamic> dataContext) {
    return data.replaceAllMapped(RegExp(r'\${(\w+)}'), (match) {
      String key = match.group(1)!;
      return dataContext.containsKey(key) ? dataContext[key]! : match.group(0)!;
    });
  }

  static Locale? getLocale(String languageCode, String? countryCode) {
    var _countryCode = countryCode?.length == 2 ? countryCode : null;
    if (kMaterialSupportedLanguages.contains(languageCode)) {
      return Locale(languageCode, _countryCode);
    }
    return null;
  }

  static BoxShape? getBoxShape(data) {
    if (data == 'circle') {
      return BoxShape.circle;
    } else if (data == 'rectangle') {
      return BoxShape.rectangle;
    }
    return null;
  }

  static BoxFit? getBoxFit(String? inputFit) {
    BoxFit? fit;
    switch (inputFit) {
      case 'fill':
        fit = BoxFit.fill;
        break;
      case 'contain':
        fit = BoxFit.contain;
        break;
      case 'cover':
        fit = BoxFit.cover;
        break;
      case 'fitWidth':
        fit = BoxFit.fitWidth;
        break;
      case 'fitHeight':
        fit = BoxFit.fitHeight;
        break;
      case 'none':
        fit = BoxFit.none;
        break;
      case 'scaleDown':
        fit = BoxFit.scaleDown;
        break;
    }
    return fit;
  }

  // To sort the list with nested map object using Key
  static List<dynamic> sortMapObjectsByKey(
      List<dynamic> dataMapObjects, String? sortKey,
      {required bool isAscendingOrder}) {
    final dataObjects = dataMapObjects.map((e) => e as Map).toList();
    if (dataObjects.isNotEmpty && sortKey != null) {
      // Function to recursively traverse the nested object and get the value of the key.
      getValue(Map<dynamic, dynamic> mapObject, String key) {
        if (mapObject.containsKey(key)) {
          return mapObject[key];
        }

        for (final nestedKey in mapObject.keys) {
          final nestedObject = mapObject[nestedKey];
          if (nestedObject is Map<dynamic, dynamic>) {
            final value = getValue(nestedObject, key);
            if (value != null) {
              return value;
            }
          }
        }

        return null;
      }

      // Comparator function to compare the values of the key in two map objects.
      int compare(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
        final aValue = getValue(a, sortKey);
        final bValue = getValue(b, sortKey);

        return isAscendingOrder
            ? aValue.compareTo(bValue)
            : bValue.compareTo(aValue);
      }

      // Sort the array of map objects using the comparator function.
      dataObjects.sort(compare);
      return dataObjects;
    }
    // Fallback - Returning same passed-in object to the caller
    return dataMapObjects;
  }

  static String generateRandomId(int length) {
    var rand = Random();
    var codeUnits = List.generate(length, (index) {
      return rand.nextInt(26) + 97; // ASCII code for lowercase a-z
    });

    return String.fromCharCodes(codeUnits);
  }
}
