
import 'package:ensemble/framework/icon.dart' as framework;
import 'package:ensemble/framework/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

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
          icon: myController.icon == null ? null : framework.Icon(
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