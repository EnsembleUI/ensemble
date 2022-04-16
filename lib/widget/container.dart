

import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/widgets.dart';
import 'package:flutter/cupertino.dart';

/// base mixin for Ensemble Container (e.g Column)
mixin UpdatableContainer {

  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate});

}


/// base controller for Column/Row
class BoxLayoutController extends WidgetController {
  dynamic onTap;

  bool scrollable = false;
  bool autoFit = false;
  String? mainAxis;
  String? crossAxis;
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




  Map<String, Function> setters() {
    return {
      'onTap': (func) => onTap = func,

      'scrollable': (value) => scrollable = value is bool ? value : false,
      'autoFit': (value) =>  autoFit = value is bool ? value : false,
      'mainAxis': (value) => mainAxis = value,
      'crossAxis': (value) => crossAxis = value,
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
      'fontFamily': (value) => fontFamily = value,
      'fontSize': (value) =>  fontSize = Utils.optionalInt(value),

      'shadowColor': (value) => shadowColor = Utils.optionalInt(value),
      'shadowOffset': (list) => shadowOffset = list is List<int> ? list : null,
      'shadowRadius': (value) =>  shadowRadius = Utils.optionalInt(value),

    };
  }

  Map<String, Function> getters() {
    return {};
  }
}