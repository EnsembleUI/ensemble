import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class StyleProvider {
  StyleProvider({this.stylesPayload}) {
    print('Styles Payload: $stylesPayload');
    if (stylesPayload != null) {
      final styleData = stylesPayload!['Styles'];
      print('YamlMap: $styleData');
      for (MapEntry entry in (styleData as YamlMap).entries) {
        // see if the custom widget actually declare any input parameters
        if (entry.key != null && entry.key != '' && entry.value is YamlMap) {
          final value = entry.value;
          final type = Utils.optionalString(value?['type']);
          final color = Utils.getColor(value?['color']);
          final backgroundColor = Utils.getColor(value?['backgroundColor']);
          final shadowColor = Utils.getColor(value?['shadowColor']);
          final borderColor = Utils.getColor(value?['borderColor']);
          final shadowRadius =
              Utils.getInt(value?['shadowRadius'], fallback: 0);
          final borderRadius =
              Utils.getInt(value?['borderRadius'], fallback: 0);
          final borderWidth = Utils.getInt(value?['borderWidth'], fallback: 0);
          final height = Utils.optionalInt(value?['height']);
          final width = Utils.optionalInt(value?['width']);
          final fontSize = Utils.optionalInt(value?['fontSize']);
          final fontWeight = Utils.optionalInt(value?['fontWeight']);

          final Map<String, StyleTheme> styleTheme = {
            entry.key: StyleTheme(
              type: type,
              height: height,
              width: width,
              color: color,
              backgroundColor: backgroundColor,
              shadowColor: shadowColor,
              borderColor: borderColor,
              shadowRadius: shadowRadius,
              borderRadius: borderRadius,
              borderWidth: borderWidth,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          };
          styles.add(styleTheme);
        }
      }
    }
  }

  final YamlMap? stylesPayload;
  List<Map<String, StyleTheme>> styles = [];

  StyleTheme? getNamedStyle(String? namedStyle) {
    if (namedStyle == null) return null;
    final styleData =
        styles.firstWhere((value) => value.containsKey(namedStyle));
    final style = styleData[namedStyle];
    return style;
  }
}

class StyleTheme {
  StyleTheme({
    this.type,
    this.color,
    this.backgroundColor,
    this.borderColor,
    this.shadowColor,
    this.borderWidth,
    this.shadowRadius,
    this.borderRadius,
    this.height,
    this.width,
    this.fontSize,
    this.fontWeight,
  });

  final String? type;
  final Color? color;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? shadowColor;
  final int? borderWidth;
  final int? shadowRadius;
  final int? borderRadius;
  final int? height;
  final int? width;
  final int? fontSize;
  final int? fontWeight;
}
