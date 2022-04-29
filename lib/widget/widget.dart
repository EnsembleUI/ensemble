import 'package:ensemble/framework/action.dart' as action;
import 'package:ensemble/framework/icon.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

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
      'expanded': (value) => expanded = Utils.getBool(value, fallback: false),
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
      'enabled': (value) => enabled = Utils.getBool(value, fallback: true),
      'required': (value) => required = Utils.getBool(value, fallback: false),
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

/// base widget state for FormField widgets
abstract class FormFieldWidgetState<W extends HasController> extends WidgetState<W> {
  // the key to validate this FormField
  final validatorKey = GlobalKey<FormFieldState>();

  /// return a default InputDecoration if the controller is a FormField
  InputDecoration get inputDecoration {
    if (widget.controller is FormFieldController) {
      FormFieldController myController = widget.controller as FormFieldController;
      return InputDecoration(
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: myController.label,
        hintText: myController.hintText,
        icon: myController.icon == null ? null : ensemble.Icon(
          myController.icon!,
          library: myController.iconLibrary,
          size: myController.iconSize,
          color:
            myController.iconColor != null ?
            Color(myController.iconColor!) :
            null)
      );
    }
    return const InputDecoration();
  }

}

/// base controller for Column/Row
class BoxLayoutController extends WidgetController {
  dynamic onTap;

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


  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'onTap': (func) => onTap = func,

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
