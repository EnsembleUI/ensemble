
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:yaml/yaml.dart';

/// base controller for Column/Row
class BoxLayoutController extends WidgetController {
  EnsembleAction? onTap;

  bool scrollable = false;
  bool autoFit = false;
  String? mainAxis;
  String? crossAxis;
  String? mainAxisSize;
  int? width;
  int? maxWidth;
  int? height;
  int? maxHeight;
  int? margin;
  int? padding;
  int? gap;

  int? backgroundColor;
  int? borderColor;
  int? borderRadius;
  String? fontFamily;
  int? fontSize;

  int? shadowColor;
  List<int>? shadowOffset;
  int? shadowRadius;

  List<Widget>? children;


  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'scrollable': (value) => scrollable = Utils.getBool(value, fallback: false),
      'autoFit': (value) =>  autoFit = Utils.getBool(value, fallback: false),
      'mainAxis': (value) => mainAxis = Utils.optionalString(value),
      'crossAxis': (value) => crossAxis = Utils.optionalString(value),
      'mainAxisSize': (value) => mainAxisSize = Utils.optionalString(value),
      'width': (value) => width = Utils.optionalInt(value),
      'maxWidth': (value) => maxWidth = Utils.optionalInt(value),
      'height': (value) => height = Utils.optionalInt(value),
      'maxHeight': (value) => maxHeight = Utils.optionalInt(value),
      'margin': (value) => margin = Utils.optionalInt(value),
      'padding': (value) => padding = Utils.optionalInt(value),
      'gap': (value) => gap = Utils.optionalInt(value),

      'backgroundColor': (value) => backgroundColor = Utils.optionalInt(value),
      'borderColor': (value) =>  borderColor = Utils.optionalInt(value),
      'borderRadius': (value) =>  borderRadius = Utils.optionalInt(value),
      'fontFamily': (value) => fontFamily = Utils.optionalString(value),
      'fontSize': (value) =>  fontSize = Utils.optionalInt(value),

      'shadowColor': (value) => shadowColor = Utils.optionalInt(value),
      'shadowOffset': (list) => setShadowOffset(list),
      'shadowRadius': (value) =>  shadowRadius = Utils.optionalInt(value),

    });
    return setters;
  }

  void setShadowOffset(dynamic offset) {
    if (offset is YamlList) {
      List<dynamic> list = offset.toList();
      if (list.length >= 2 && list[0] is int && list[1] is int) {
        shadowOffset = [list[0], list[1]];
      } else {
        shadowOffset = null;
      }
    }
  }
}