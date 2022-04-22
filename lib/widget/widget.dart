import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:sdui/invokables/invokable.dart';

/// base mixin for Ensemble Container (e.g Column)
mixin UpdatableContainer {
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate});
}


/// base Controller class for your Ensemble widget
abstract class WidgetController extends Controller {

  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets
  bool expanded = false;
  //int? padding;

  @override
  Map<String, Function> getBaseGetters() {
    return {
      'expanded': () => expanded,
      //'padding': () => padding,
    };
  }

  @override
  Map<String, Function> getBaseSetters() {
    return {
      'expanded': (value) => expanded = value is bool ? value : false,
      //'padding': (value) => padding = Utils.optionalInt(value),
    };
  }
}

/// Controls attributes applicable for all Form Field widgets.
class FormFieldController extends WidgetController {
  bool enabled = true;
  bool required = false;
  String? label;
  String? hintText;
  String? icon;
  String? iconLibrary;
  int? iconSize;
  int? iconColor;

  @override
  Map<String, Function> getBaseGetters() {
    Map<String, Function> getters = super.getBaseGetters();
    getters.addAll({
      'enabled': () => enabled,
      'required': () => required,
      'label': () => label,
      'hintText': () => hintText,
    });
    return getters;
  }

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'enabled': (value) => enabled = value is bool ? value : true,
      'required': (value) => required = value is bool ? value : false,
      'label': (value) => label = Utils.optionalString(value),
      'hintText': (value) => hintText = Utils.optionalString(value),
      'icon': (value) => icon = Utils.optionalString(value),
      'iconLibrary': (value) => iconLibrary = Utils.optionalString(value),
      'iconSize': (value) => iconSize = Utils.optionalInt(value),
      'iconColor': (value) => iconColor = Utils.optionalInt(value),
    });
    return setters;
  }

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


  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
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

    });
    return setters;
  }
}