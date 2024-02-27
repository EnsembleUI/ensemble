import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

class EnsembleThemeManager {
  static final EnsembleThemeManager _instance =
      EnsembleThemeManager._internal();
  static final Map<String, EnsembleTheme> _themes = {};
  String _currentThemeName =
      'root'; //temporary name till we support multiple themes
  EnsembleThemeManager._internal();

  factory EnsembleThemeManager() {
    return _instance;
  }

  /// this is name/value map. name being the name of the theme and value being the theme map
  void init(Map<String, YamlMap> themeMap, String currentThemeName) {
    _currentThemeName = currentThemeName;
    for (var theme in themeMap.entries) {
      _themes[theme.key] = _parseTheme(theme.value);
    }
  }

  EnsembleTheme _parseTheme(YamlMap yamlTheme) {
    dynamic theme = _yamlToDart(yamlTheme);
    _convertKeysToCamelCase(theme['InheritableStyles']);
    _convertKeysToCamelCase(theme['Styles']);
    return EnsembleTheme(
      tokens: theme['Tokens'] ?? {},
      styles: theme['Styles'] ?? {},
      inheritableStyles: theme['InheritableStyles'] ?? {},
    );
  }

  SupportsThemes applyTheme(BuildContext context, SupportsThemes model,
      Map<String, dynamic>? parentStyles) {
    _themes[_currentThemeName]?.apply(context, model, parentStyles ?? {});
    return model;
  }

  EnsembleTheme? currentTheme() {
    return _themes[_currentThemeName];
  }

  static dynamic _yamlToDart(dynamic yamlElement) {
    if (yamlElement is YamlMap) {
      return yamlElement
          .map((key, value) => MapEntry(key.toString(), _yamlToDart(value)));
    } else if (yamlElement is YamlList) {
      return yamlElement.map((value) => _yamlToDart(value)).toList();
    }
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
        .map((index, word) => MapEntry(index, index > 0 ? word[0].toUpperCase() + word.substring(1) : word))
        .values
        .join('');
  }
}

class StyleResolver {
  final EnsembleTheme theme;
  final Map<String, dynamic> screenDefinition;
  StyleResolver(this.theme, this.screenDefinition);

  void applyStyles() {}
}

class EnsembleTheme {
  Map<String,dynamic> tokens;
  Map<String, dynamic> styles;
  Map<String, dynamic> inheritableStyles;
  bool areTokensResolved = false;

  EnsembleTheme(
      {required this.tokens,
      required this.styles,
      required this.inheritableStyles});

  void apply(BuildContext context, SupportsThemes model,
      Map<String, dynamic> inheritedStyles) {
    DataContext dataContext =
        DataContext(buildContext: context, initialMap: tokens);
    if (!areTokensResolved) {
      _resolveTokens(dataContext);
    }
    model.applyTheme(dataContext, inheritedStyles);
  }

  Map<String, dynamic> getInheritableStyles(Map<String, dynamic> styles) {
    Map<String, dynamic> inheritedStyles = {};
    void inheritStyles(
        Map<String, dynamic> currentStyles,
        Map<String, dynamic> currentInheritable,
        Map<String, dynamic> currentInherited) {
      currentStyles.forEach((key, value) {
        // Check if the current key is inheritable
        if (currentInheritable.containsKey(key)) {
          // If the value is also a map, we need to recurse
          if (value is Map<String, dynamic> && currentInheritable[key] is Map<String, dynamic>) {
            Map<String, dynamic> newNestedInherited = {};
            inheritStyles(value, currentInheritable[key], newNestedInherited);
            if (newNestedInherited.isNotEmpty) {
              currentInherited[key] = newNestedInherited;
            }
          } else {
            // Otherwise, directly inherit the style
            currentInherited[key] = value;
          }
        }
      });
    }
    inheritStyles(styles, inheritableStyles, inheritedStyles);
    return inheritedStyles;
  }
  void applyStylesToWidget(WidgetModel model, DataContext dataContext, Map<String,dynamic> inheritedStyles) {
    //first we will merge the associated styles from theme - styles specified with id overwrite the ones specified with widget type
    String? widgetId = model.props['id'];
    Map<String, dynamic>? idStyles =
        (widgetId == null) ? {} : styles['#$widgetId'];
    model.styles = resolveStyles(
        dataContext,
        model.styles,
        model.classList,
        mergeMaps(styles[model.type], idStyles),
        getInheritableStyles(inheritedStyles));
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
          result[key] = mergeMaps(result[key] as Map<String, dynamic>, value as Map<String,dynamic>);
        } else {
          // Otherwise, just set/overwrite the value
          result[key] = value;
        }
      });
    }
    return result;
  }
  //precedence order is exactly in the order of arguments in this method
  Map<String,dynamic> resolveStyles(DataContext context,
      Map<String,dynamic>? inlineStyles, //inline styles specified on the widget
      List<String>? classList, //namedstyles specified on the widget
      Map<String,dynamic>? themeStyles, //styles specified in themes - could be by widget type or id
      Map<String,dynamic>? inheritedStyles //styles inherited from ancestors that are inheritable styles
      ) {
    Map<String,dynamic> resolvedStyles = resolveClassList(classList);
    //return {...?inheritedStyles, ...resolvedStyles, ...?inlineStyles}; //I SOOOOO LOVE this syntax but can't use it here
    Map<String, dynamic> combinedStyles =
        mergeMaps(
            mergeMaps(
                mergeMaps(
                    inheritedStyles, themeStyles
                ),
                resolvedStyles
            ), inlineStyles
        );
    context.eval(combinedStyles);
    return combinedStyles;
  }
  void _resolveTokens(DataContext dataContext) {
    // resolve tokens
    for ( var key in styles.keys ) {
      styles[key] = dataContext.eval(styles[key]);
    }
    areTokensResolved = true;
  }

}