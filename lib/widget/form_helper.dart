
import 'package:ensemble/framework/widget/icon.dart' as framework;
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/layout/form.dart' as ensemble;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/theme_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Controls attributes applicable for all Form Field widgets.
class FormFieldController extends WidgetController {
  bool? enabled;
  bool required = false;
  String? hintText;
  String? icon;
  String? iconLibrary;
  int? iconSize;
  int? iconColor;
  int? fontSize;

  @override
  Map<String, Function> getBaseGetters() {
    Map<String, Function> getters = super.getBaseGetters();
    getters.addAll({
      'enabled': () => enabled,
      'required': () => required,
    });
    return getters;
  }

  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'enabled': (value) => enabled = Utils.optionalBool(value),
      'required': (value) => required = Utils.getBool(value, fallback: false),
      'hintText': (value) => hintText = Utils.optionalString(value),
      'icon': (value) => icon = Utils.optionalString(value),
      'iconLibrary': (value) => iconLibrary = Utils.optionalString(value),
      'iconSize': (value) => iconSize = Utils.optionalInt(value),
      'iconColor': (value) => iconColor = Utils.optionalInt(value),
      'fontSize': (value) => fontSize = Utils.optionalInt(value),
    });
    return setters;
  }

  void submitForm(BuildContext context) {
    FormHelper.submitForm(context);
  }


}

class FormHelper {
  /// submit if inside a Form
  static void submitForm(BuildContext context) {
    ensemble.FormState? formState = EnsembleForm.of(context);
    if (formState != null) {
      // don't continue if validation fails
      if (!formState.validate()) {
        return;
      }
      if (formState.widget.controller.onSubmit != null) {
        ScreenController().executeAction(context, formState.widget.controller.onSubmit!);
      }
    }
  }
}

/// base widget state for FormField widgets
abstract class FormFieldWidgetState<W extends HasController> extends WidgetState<W> {
  // the key to validate this FormField
  final validatorKey = GlobalKey<FormFieldState>();

  /// return a default InputDecoration if the controller is a FormField
  InputDecoration get inputDecoration {
    if (widget.controller is FormFieldController) {
      FormFieldController myController = widget
          .controller as FormFieldController;
      return InputDecoration(
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelText: shouldShowLabel() ? myController.label : null,
          hintText: myController.hintText,
          icon: myController.icon == null ? null : framework.Icon(
              myController.icon!,
              library: myController.iconLibrary,
              size: myController.iconSize,
              color: myController.iconColor != null ?
                Color(myController.iconColor!) :
                null)
      );
    }
    return const InputDecoration();
  }

  /// return the field's enabled, fallback to parent Form's enabled,
  /// then fallback to TRUE
  bool isEnabled() {
    if (widget.controller is FormFieldController) {
      return (widget.controller as FormFieldController).enabled
          ?? EnsembleForm.of(context)?.widget.controller.enabled
          ?? true;
    }
    return true;
  }

  bool shouldShowLabel() {
    ensemble.FormState? formState = EnsembleForm.of(context);
    if (formState != null) {
      return formState.widget.shouldFormFieldShowLabel;
    }
    return true;
  }
}