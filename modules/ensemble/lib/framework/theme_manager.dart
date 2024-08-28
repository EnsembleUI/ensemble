import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class EnsembleThemeManager {
  static final EnsembleThemeManager _instance =
  EnsembleThemeManager._internal();
  static final Map<String, EnsembleTheme> _themes = {};
  static final Map<String, List<dynamic>> _localeThemes = {};
  static final Map<String, String> _defaultLocaleThemes = {};

  static const defaultThemeWhenNoneSpecified = '__ensemble__default__theme';
  String _currentThemeName = defaultThemeWhenNoneSpecified;
  String? _currentLocale;
  String? get currentLocale => _currentLocale;
  String get currentThemeName => _currentThemeName;
  bool initialized = false;

  EnsembleThemeManager._internal();

  factory EnsembleThemeManager() {
    return _instance;
  }

  List<String> getThemeNames() {
    return _themes.keys.toList();
  }

  EnsembleTheme? getTheme(String theme) {
    return _themes[theme];
  }

  void reset() {
    _themes.clear();
    _currentThemeName = defaultThemeWhenNoneSpecified;
    initialized = false;
  }

  void setTheme(String theme, {bool notifyListeners = true}) {
    if (_currentThemeName != theme) {
      if (_themes[theme] != null) {
        _currentThemeName = theme;
        // Only notify listeners if notifyListeners is true
        if (notifyListeners) {
          AppEventBus().eventBus.fire(ThemeChangeEvent(theme));
        }
      }
    }
  }

  void setCurrentLocale(String? locale, {bool notifyListeners = true}) {
    if (_currentLocale != locale) {
      _currentLocale = locale;
      _handleLocaleChange(locale, notifyListeners: notifyListeners);
    }
  }
  void _handleLocaleChange(String? locale, {bool notifyListeners = true}) {
    if (locale == null || !_localeThemes.containsKey(locale)) {
      return; // If the locale is null or not in _localeThemes, do nothing
    }

    // Get the list of themes for the new locale
    List<dynamic> localeThemeList = _localeThemes[locale]!;

    // Check if the current theme is in the list of themes for the new locale
    if (localeThemeList.contains(_currentThemeName)) {
      return; // Current theme is valid for the new locale, so do nothing
    }

    // Find the default theme for the new locale
    String? defaultThemeForLocale = _defaultLocaleThemes[locale];

    // If a default theme is found, set it as the current theme
    if (defaultThemeForLocale != null) {
      setTheme(defaultThemeForLocale, notifyListeners: notifyListeners);
    }
  }

  Map<String, dynamic>? getRuntimeStyles(
      DataContext context, HasStyles hasStyles) {
    if (currentTheme() == null) {
      //looks like there is no theme, so we'll just use the inline styles as is
      return hasStyles.inlineStyles;
    }
    return currentTheme()?.resolveStyles(context, hasStyles);
  }
  void configureStyles(
      DataContext dataContext, HasStyles model, HasStyles hasStyles) {
    //we have to set all these so we can resolve when styles change at runtime through app logic
    hasStyles.widgetType = model.widgetType;
    hasStyles.widgetTypeStyles = model.widgetTypeStyles;
    hasStyles.widgetId = model.widgetId;
    hasStyles.idStyles = model.idStyles;
    //https://github.com/EnsembleUI/ensemble/issues/1491 we have to evaluate the classList here as it
    //could be a dynamic expression such as ${ensemble.storage.classses[0]. If we don't evaluate it here, our
    //runtime styles will not be able to resolve the classList and as a result will be incorrect.
    //Note that such an evaluation is only required for classList as other styles will get evaluated when
    //runtimeStyles are evaluated.
    dynamic classList = dataContext.eval(model.classList);
    if (classList is List) {
      hasStyles.classList = classList.map((item) => item as String).toList();
    }
    hasStyles.inlineStyles = model.inlineStyles;
    hasStyles.runtimeStyles = getRuntimeStyles(dataContext, hasStyles);
  }

  /// this is name/value map. name being the name of the theme and value being the theme map
  void init(BuildContext context, Map<String, YamlMap> themeMap,
      String defaultThemeName, {YamlMap? localeThemes}) {
    _currentThemeName = defaultThemeName;
    for (var theme in themeMap.entries) {
      _themes[theme.key] = _parseAndInitTheme(theme.key, theme.value, context);
    }
    _parseLocaleThemes(localeThemes);
    initialized = true;
  }
  void _parseLocaleThemes(YamlMap? localeThemes) {
    if (localeThemes != null) {
      for (var localeEntry in localeThemes.entries) {
        String locale = localeEntry.key;
        List<dynamic> themesList = localeEntry.value.map((themeYaml) {
          if (themeYaml is YamlMap) {
            return themeYaml.entries.first.key.toString();
          } else if (themeYaml is String) {
            return themeYaml;
          }
          return null;
        }).whereType<String>().toList();

        _localeThemes[locale] = themesList;

        // Determine the default theme for the locale
        String? defaultTheme;
        for (var themeYaml in localeEntry.value) {
          if (themeYaml is YamlMap && themeYaml.entries.first.value['default'] == true) {
            defaultTheme = themeYaml.entries.first.key.toString();
            break;
          }
        }

        // If no default theme is specified, use the first theme in the list
        _defaultLocaleThemes[locale] = defaultTheme ?? themesList.first;
      }
    }
  }

  EnsembleTheme _parseAndInitTheme(
      String name, YamlMap yamlTheme, BuildContext context) {
    dynamic theme = yamlToDart(yamlTheme);
    //_convertKeysToCamelCase(theme['InheritableStyles']);
    _convertKeysToCamelCase(theme['Styles']);
    return EnsembleTheme(
        name: name,
        label: theme['Label'] ?? '',
        description: theme['description'],
        inheritsFrom: theme['inheritsFrom'],
        tokens: theme['Tokens'] ?? {},
        styles: theme['Styles'] ?? {},
        inheritableStyles: {} //turning off inheritance as it is handled by the containers
    ).init(context);
  }

  EnsembleTheme? currentTheme() {
    return _themes[_currentThemeName];
  }

  static dynamic yamlToDart(dynamic yamlElement) {
    // Convert YamlMap to Dart Map
    if (yamlElement is YamlMap) {
      return yamlElement
          .map((key, value) => MapEntry(key.toString(), yamlToDart(value)));
    }
    // Convert YamlList to Dart List
    else if (yamlElement is YamlList) {
      return yamlElement.map((value) => yamlToDart(value)).toList();
    }
    // Convert Dart Map to a new Map with converted values
    else if (yamlElement is Map) {
      var newMap = <String, dynamic>{};
      yamlElement.forEach((key, value) {
        newMap[key.toString()] = yamlToDart(value);
      });
      return newMap;
    }
    // Convert Dart List to a new List with converted values
    else if (yamlElement is List) {
      return yamlElement.map((value) => yamlToDart(value)).toList();
    }
    // Return the element directly if it's neither a YamlMap, YamlList, Map, nor List
    return yamlElement;
  }

  //recursively convert keys to camel case except for the ones that start with . or #
  void _convertKeysToCamelCase(dynamic value) {
    if (value is Map) {
      final keys = value.keys.toList(growable: false);
      for (final key in keys) {
        String newKey = key;
        //we don't want to convert keys that start with . or # as they are used for class and id
        if (!key.startsWith('.') && !key.startsWith('#')) {
          newKey = _toCamelCase(key);
        }
        final val = value[key];
        value.remove(key);
        value[newKey] = val;
        _convertKeysToCamelCase(val); // Recursive call for nested maps
      }
    } else if (value is List) {
      for (final item in value) {
        _convertKeysToCamelCase(item); // Recursive call for items in lists
      }
    }
  }

  String _toCamelCase(String str) {
    return str
        .split('-')
        .asMap()
        .map((index, word) => MapEntry(index,
        index > 0 ? word[0].toUpperCase() + word.substring(1) : word))
        .values
        .join('');
  }
}

class EnsembleTheme {
  String name, label;
  String? inheritsFrom, description;
  Map<String, dynamic> tokens;
  Map<String, dynamic> styles;
  Map<String, dynamic> inheritableStyles;
  ThemeData? appThemeData;//app level theme data
  bool initialized = false;

  EnsembleTheme(
      {required this.name,
        required this.label,
        this.description,
        this.inheritsFrom,
        required this.tokens,
        required this.styles,
        required this.inheritableStyles});

  EnsembleTheme init(BuildContext context) {
    if (initialized) {
      return this;
    }
    if (inheritsFrom != null) {
      EnsembleTheme? parentTheme =
      EnsembleThemeManager().getTheme(inheritsFrom!);
      if (parentTheme != null) {
        parentTheme.init(context);
        tokens = mergeMaps(parentTheme.tokens, tokens);
        styles = mergeMaps(parentTheme.styles, styles);
        inheritableStyles =
            mergeMaps(parentTheme.inheritableStyles, inheritableStyles);
      }
    }
    DataContext dataContext =
    DataContext(buildContext: context, initialMap: tokens);
    _resolveTokens(dataContext);
    initAppThemeData();
    initialized = true;
    return this;
  }
  void initAppThemeData() {
    YamlMap? yamlStyles = styles != null ? YamlMap.wrap(styles) : null;
    appThemeData = ThemeManager().getAppTheme(yamlStyles,widgetOverrides: yamlStyles);
  }
  Map<String, dynamic>? getIDStyles(String? id) {
    return (id == null) ? {} : styles['#$id'];
  }

  Map<String, dynamic>? getThemeStyles(String? id, String type) {
    Map<String, dynamic>? idStyles = (id == null) ? {} : styles['#$id'];
    return mergeMaps(styles[type], idStyles);
  }

  Map<String, dynamic> getInheritableStyles(Map<String, dynamic>? styles) {
    //turning off inheritance
    return {};
    // Map<String, dynamic> inheritedStyles = {};
    // void inheritStyles(
    //     Map<String, dynamic> currentStyles,
    //     Map<String, dynamic> currentInheritable,
    //     Map<String, dynamic> currentInherited) {
    //   currentStyles.forEach((key, value) {
    //     // Check if the current key is inheritable
    //     if (currentInheritable.containsKey(key)) {
    //       // If the value is also a map, we need to recurse
    //       if (value is Map<String, dynamic> &&
    //           currentInheritable[key] is Map<String, dynamic>) {
    //         Map<String, dynamic> newNestedInherited = {};
    //         inheritStyles(value, currentInheritable[key], newNestedInherited);
    //         if (newNestedInherited.isNotEmpty) {
    //           currentInherited[key] = newNestedInherited;
    //         }
    //       } else {
    //         // Otherwise, directly inherit the style
    //         currentInherited[key] = value;
    //       }
    //     }
    //   });
    // }
    //
    // inheritStyles(styles, inheritableStyles, inheritedStyles);
    // return inheritedStyles;
  }

  Map<String, dynamic>? getWidgetTypeStyles(String? widgetType) {
    return widgetType != null ? styles[widgetType] : null;
  }

  void resolveAndApplyStyles(
      ScopeManager scopeManager, HasStyles controller, Invokable widget) {
    Map<String, dynamic> resolvedStyles =
    resolveStyles(scopeManager.dataContext, controller);
    controller.runtimeStyles = resolvedStyles;
    scopeManager.setProperties(scopeManager, widget, controller.runtimeStyles!);
  }

  Map<String, dynamic> resolveStyles(DataContext context, HasStyles widget) {
    return _resolveStyles(
        context,
        widget.styleOverrides,
        widget.inlineStyles,
        getIDStyles(widget.widgetId),
        widget.classList,
        getWidgetTypeStyles(widget.widgetType),
        null);
  }

  ///classList is a list of class names
  Map<String, dynamic> resolveClassList(List<String>? classList) {
    Map<String, dynamic> resolvedStyles = {};
    if (classList == null) {
      return resolvedStyles;
    }
    for (String className in classList) {
      String key = '.$className'; // Prepend '.' to match the style keys
      var classStyle = styles[key];
      if (classStyle != null) {
        resolvedStyles = mergeMaps(resolvedStyles, classStyle);
      }
    }
    return resolvedStyles;
  }

  ///remember styles could be nested (for example textStyles under styles) so we have to merge them recursively at the style property level
  Map<String, dynamic> mergeMaps(
      Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
    Map<String, dynamic> result = {};

    // Add all values from the first map to the result
    if (map1 != null) {
      result.addAll(map1);
    }

    // Merge values from the second map
    if (map2 != null) {
      map2.forEach((key, value) {
        // If both maps contain a Map for the same key, merge them recursively
        if (result[key] != null && result[key] is Map && value is Map) {
          result[key] = mergeMaps(result[key] as Map<String, dynamic>,
              value as Map<String, dynamic>);
        } else if (key == 'margin' || key == 'padding') {
          // Handle margin and padding specifically as they need to be merged at the edge level
          result[key] = mergeEdgeInsets(
              (result[key] is int)?result[key].toString():result[key],
              (value is int)?value.toString():value);
        } else {
          result[key] = value;
        }
      });
    }
    return result;
  }

  List<String> normalizeEdgeInsets(String value) {
    // Split the value by spaces and normalize to a list of four values
    List<String> parts = value.split(' ');

    if (parts.length == 1) {
      // All sides are the same
      return [parts[0], parts[0], parts[0], parts[0]];
    } else if (parts.length == 2) {
      // Top/Bottom are the first value, Left/Right are the second value
      return [parts[0], parts[1], parts[0], parts[1]];
    } else if (parts.length == 3) {
      // Top is the first, Left/Right are the second, Bottom is the third
      return [parts[0], parts[1], parts[2], parts[1]];
    } else if (parts.length == 4) {
      // All sides are specified
      return parts;
    }

    // Fallback if something unexpected happens
    return ['0', '0', '0', '0'];
  }

  String? mergeEdgeInsets(dynamic value1, dynamic value2) {
    if (value1 == null) {
      return value2;
    }

    if (value2 == null) {
      return value1;
    }

    // Normalize both values to lists of four values
    List<String> normalized1 = normalizeEdgeInsets(value1.toString());
    List<String> normalized2 = normalizeEdgeInsets(value2.toString());

    // Merge by using the value from map2 if it exists, otherwise fallback to map1
    List<String> merged = [
      normalized2[0] + '' != '0' ? normalized2[0] : normalized1[0],
      normalized2[1] + '' != '0' ? normalized2[1] : normalized1[1],
      normalized2[2] + '' != '0' ? normalized2[2] : normalized1[2],
      normalized2[3] + '' != '0' ? normalized2[3] : normalized1[3],
    ];

    return merged.join(' ');
  }


  //precedence order is exactly in the order of arguments in this method
  Map<String, dynamic> _resolveStyles(
      DataContext context,
      Map<String, dynamic>? styleOverrides,
      //styles overriden in app logic (e.g. through js)
      Map<String, dynamic>?
      inlineStyles, //inline styles specified on the widget
      Map<String, dynamic>? idStyles,
      List<String>? classList, //namedstyles specified on the widget
      Map<String, dynamic>? widgetTypeStyles,
      //styles specified in themes - could be by widget type or id
      Map<String, dynamic>? inheritedStyles
      //styles inherited from ancestors that are inheritable styles
      ) {
    Map<String, dynamic> resolvedStyles = resolveClassList(classList);
    Map<String, dynamic> combinedStyles = mergeMaps(
        mergeMaps(
            mergeMaps(
                mergeMaps(mergeMaps(inheritedStyles, widgetTypeStyles),
                    resolvedStyles),
                idStyles),
            inlineStyles),
        styleOverrides);
    context.eval(combinedStyles);
    return combinedStyles;
  }

  void _resolveTokens(DataContext dataContext) {
    // resolve tokens
    for (var key in styles.keys) {
      styles[key] = dataContext.eval(styles[key]);
    }
  }
}

class ThemeProvider extends InheritedWidget {
  final EnsembleTheme theme;

  const ThemeProvider({super.key, required Widget child, required this.theme})
      : super(child: child);

  @override
  bool updateShouldNotify(ThemeProvider oldWidget) => theme != oldWidget.theme;

  static ThemeProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<ThemeProvider>();
  }
}
