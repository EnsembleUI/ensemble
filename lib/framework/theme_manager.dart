import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

class EnsembleThemeManager {
  static final EnsembleThemeManager _instance =
      EnsembleThemeManager._internal();
  static final Map<String, EnsembleTheme> _themes = {};
  String _currentThemeName = 'root';

  EnsembleThemeManager._internal();

  factory EnsembleThemeManager() {
    return _instance;
  }

  EnsembleTheme? getTheme(String theme) {
    return _themes[theme];
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
    hasStyles.themeStyles = model.themeStyles;
    hasStyles.classList = model.classList;
    hasStyles.inlineStyles = model.inlineStyles;
    hasStyles.runtimeStyles = getRuntimeStyles(dataContext, hasStyles);
  }

  /// this is name/value map. name being the name of the theme and value being the theme map
  void init(BuildContext context, Map<String, YamlMap> themeMap,
      String currentThemeName) {
    _currentThemeName = currentThemeName;
    for (var theme in themeMap.entries) {
      _themes[theme.key] = _parseAndInitTheme(theme.key, theme.value, context);
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
    initialized = true;
    return this;
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

  Map<String, dynamic>? getWidgetTypeStyles(String widgetType) {
    return styles[widgetType];
  }

  void resolveAndApplyStyles(ScopeManager scopeManager, HasStyles controller, Invokable widget) {
    Map<String, dynamic> resolvedStyles =
    resolveStyles(scopeManager.dataContext, controller);
    controller.runtimeStyles = resolvedStyles;
    scopeManager.setProperties(scopeManager, controller.runtimeStyles!, widget);
  }

  Map<String, dynamic> resolveStyles(DataContext context, HasStyles widget) {
    return _resolveStyles(context, widget.styleOverrides, widget.inlineStyles,
        widget.classList, widget.themeStyles, null);
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
        resolvedStyles = {...resolvedStyles, ...classStyle};
      }
    }
    return resolvedStyles;
  }

  ///remember styles could be nested (for example textStyles under styles) so we have to merge them recursively at the style property level
  Map<String, dynamic> mergeMaps(Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
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
        } else {
          // Otherwise, just set/overwrite the value
          result[key] = value;
        }
      });
    }
    return result;
  }

  //precedence order is exactly in the order of arguments in this method
  Map<String, dynamic> _resolveStyles(DataContext context,
      Map<String, dynamic>? styleOverrides,
      //styles overriden in app logic (e.g. through js)
      Map<String, dynamic>?
      inlineStyles, //inline styles specified on the widget
      List<String>? classList, //namedstyles specified on the widget
      Map<String, dynamic>?
      themeStyles, //styles specified in themes - could be by widget type or id
      Map<String, dynamic>? inheritedStyles
      //styles inherited from ancestors that are inheritable styles
      ) {
    Map<String, dynamic> resolvedStyles = resolveClassList(classList);
    Map<String, dynamic> combinedStyles = mergeMaps(
        mergeMaps(
            mergeMaps(mergeMaps(inheritedStyles, themeStyles), resolvedStyles),
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
