import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/framework/widget/icon.dart' as framework;
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/form.dart';
import 'package:ensemble/layout/form.dart' as ensemble;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/input/form_textfield.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// Controls attributes applicable for all Form Field widgets.
class FormFieldController extends WidgetController {
  String? labelText;
  String? labelHint;
  TextStyle? labelStyle;
  bool? floatLabel;
  TextStyle? floatingLabelStyle;

  String? description;

  bool? enabled;
  bool required = false;
  String? requiredMessage;
  TextStyle? errorStyle;
  IconModel? icon;
  int? maxWidth;

  InputVariant? variant;
  EdgeInsets? contentPadding;
  bool? filled;
  Color? fillColor;

  EBorderRadius? borderRadius;
  int? borderWidth;
  Color? borderColor;

  Color? enabledBorderColor;
  Color? disabledBorderColor;
  Color? errorBorderColor;
  Color? focusedBorderColor;
  Color? focusedErrorBorderColor;
  
  BuildContext? _context;
  void setContext(BuildContext? context) {
    _context = context;
  }
  BuildContext? get context => _context;

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
      'floatLabel': (value) =>
          floatLabel = Utils.getBool(value, fallback: false),
      'required': (value) => required = Utils.getBool(value, fallback: false),
      'requiredMessage': (value) => requiredMessage =
          Utils.getString(value, fallback: 'This field is required'),
      'icon': (value) => icon = Utils.getIcon(value),
      'maxWidth': (value) =>
          maxWidth = Utils.optionalInt(value, min: 0, max: 5000),
      'variant': (type) => variant = InputVariant.values.from(type),
      'contentPadding': (value) => contentPadding = Utils.optionalInsets(value),
      'filled': (value) => filled = Utils.optionalBool(value),
      'fillColor': (value) => fillColor = Utils.getColor(value),
      'borderRadius': (value) => borderRadius = Utils.getBorderRadius(value),
      'borderWidth': (value) => borderWidth = Utils.optionalInt(value, min: 0),
      'borderColor': (color) => borderColor = Utils.getColor(color),
      'enabledBorderColor': (color) =>
          enabledBorderColor = Utils.getColor(color),
      'disabledBorderColor': (color) =>
          disabledBorderColor = Utils.getColor(color),
      'errorBorderColor': (color) => errorBorderColor = Utils.getColor(color),
      'focusedBorderColor': (color) =>
          focusedBorderColor = Utils.getColor(color),
      'focusedErrorBorderColor': (color) =>
          focusedErrorBorderColor = Utils.getColor(color),
      'labelStyle': (style) => labelStyle = Utils.getTextStyle(style),
      'errorStyle': (style) => errorStyle = Utils.getTextStyle(style),
      'floatingLabelStyle': (style) =>
          floatingLabelStyle = Utils.getTextStyle(style),
      'label': (value) => label = Utils.optionalString(value),
      'labelText': (value) => labelText = Utils.optionalString(value),
      'labelHint': (value) => labelHint = Utils.optionalString(value),
      'description': (value) => description = Utils.optionalString(value),
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
        ScreenController().executeAction(
            context, formState.widget.controller.onSubmit!,
            event: EnsembleEvent(formState.widget));
      }
    }
  }
}

/// base widget state for FormField widgets
abstract class FormFieldWidgetState<W extends HasController>
    extends EWidgetState<W> {
  // the key to validate this FormField
  final validatorKey = GlobalKey<FormFieldState>();

  /// return a default InputDecoration if the controller is a FormField
  /// Note that all fields here are inherited from InputDecorationTheme
  /// which is defined at the Ensemble theme level. Hence only override
  /// the attributes that are specified manually by the user at each input.
  InputDecoration get inputDecoration {
    if (widget.controller is FormFieldController) {
      FormFieldController myController =
          widget.controller as FormFieldController;
      InputDecorationTheme themeDecoration =
          Theme.of(context).inputDecorationTheme;

      // if the theme has fill color, we don't want to disable that just because
      // the user doesn't manually override the fill color here. Make sure it is
      // null or true only (never false)
      bool? filled;
      if (myController.fillColor != null) {
        filled = true;
      }

      // IMPORTANT:
      // 1. If the variant, borderWidth or borderRadius is override here, we
      // have to redraw ALL the borders.
      // 2. If a borderColor is override here, we can just redraw that border

      // Use redrawAllBorders as the flag to know if we should redraw all
      bool redrawAllBorders = false;

      // resolve the variant
      InputVariant? _themeVariant = themeDecoration.border is OutlineInputBorder
          ? InputVariant.box
          : null;
      if (myController.variant != null &&
          myController.variant != _themeVariant) {
        redrawAllBorders = true;
      }
      InputVariant? variant = myController.variant ?? _themeVariant;

      // resolve borderWidth
      int? _themeBorderWidth = themeDecoration.border?.borderSide.width.toInt();
      if (myController.borderWidth != null &&
          myController.borderWidth != _themeBorderWidth) {
        redrawAllBorders = true;
      }
      int borderWidth = myController.borderWidth ?? _themeBorderWidth ?? 1;

      // resolve borderRadius
      BorderRadius? _themeBorderRadius =
          themeDecoration.border is UnderlineInputBorder
              ? (themeDecoration.border as UnderlineInputBorder).borderRadius
              : themeDecoration.border is OutlineInputBorder
                  ? (themeDecoration.border as OutlineInputBorder).borderRadius
                  : null;
      if (myController.borderRadius != null &&
          myController.borderRadius!.getValue() != _themeBorderRadius) {
        redrawAllBorders = true;
      }
      BorderRadius borderRadius = myController.borderRadius?.getValue() ??
          _themeBorderRadius ??
          ThemeManager().getInputDefaultBorderRadius(variant);

      return InputDecoration(
          // consistent with the theme. We need dense so user have granular control of contentPadding
          isDense: true,
          filled: filled,
          fillColor: myController.fillColor,
          // labelText: shouldShowLabel() ? myController.label : null,
          hintText: myController is HasTextPlaceholder
              ? myController.placeholder ?? myController.hintText
              : null,
          hintStyle: myController is HasTextPlaceholder
              ? myController.placeholderStyle ?? myController.hintStyle
              : null,
          prefixIcon: myController.icon == null
              ? null
              : framework.Icon(
                  myController.icon!.icon,
                  library: myController.icon!.library,
                  size: myController.icon!.size ??
                      ThemeManager().getInputIconSize(context),
                  color: myController.icon!.color ??
                      Theme.of(context).inputDecorationTheme.iconColor,
                ),
          contentPadding: myController.contentPadding,

          // only redraw the border if necessary, as we will fallback
          // to theme
          border: myController.borderColor == null && !redrawAllBorders
              ? null
              : ThemeManager().getInputBorder(
                  variant: variant,
                  borderWidth: borderWidth,
                  borderRadius: borderRadius,
                  borderColor: myController.borderColor ??
                      themeDecoration.border?.borderSide.color),
          enabledBorder: myController.enabledBorderColor == null && !redrawAllBorders
              ? null
              : ThemeManager().getInputBorder(
                  variant: variant,
                  borderWidth: borderWidth,
                  borderRadius: borderRadius,
                  borderColor: myController.enabledBorderColor ??
                      themeDecoration.enabledBorder?.borderSide.color ??
                      themeDecoration.border?.borderSide.color),
          disabledBorder: myController.disabledBorderColor == null && !redrawAllBorders
              ? null
              : ThemeManager().getInputBorder(
                  variant: variant,
                  borderWidth: borderWidth,
                  borderRadius: borderRadius,
                  borderColor: myController.disabledBorderColor ??
                      themeDecoration.disabledBorder?.borderSide.color),
          errorBorder: myController.errorBorderColor == null && !redrawAllBorders
              ? null
              : ThemeManager().getInputBorder(
                  variant: variant,
                  borderWidth: borderWidth,
                  borderRadius: borderRadius,
                  borderColor: myController.errorBorderColor ??
                      themeDecoration.errorBorder?.borderSide.color),
          focusedBorder: myController.focusedBorderColor == null && !redrawAllBorders
              ? null
              : ThemeManager().getInputBorder(
                  variant: variant,
                  borderWidth: borderWidth,
                  borderRadius: borderRadius,
                  borderColor: myController.focusedBorderColor ??
                      themeDecoration.focusedBorder?.borderSide.color),
          focusedErrorBorder: myController.focusedErrorBorderColor == null && !redrawAllBorders
              ? null
              : ThemeManager().getInputBorder(
                  variant: variant,
                  borderWidth: borderWidth,
                  borderRadius: borderRadius,
                  borderColor: myController.focusedErrorBorderColor ??
                      themeDecoration.focusedErrorBorder?.borderSide.color),
          labelStyle: myController.labelStyle,
          floatingLabelStyle: myController.floatingLabelStyle);
    }
    return const InputDecoration();
  }

  /// return the field's enabled, fallback to parent Form's enabled,
  /// then fallback to TRUE
  bool isEnabled() {
    if (widget.controller is FormFieldController) {
      return (widget.controller as FormFieldController).enabled ??
          EnsembleForm.of(context)?.widget.controller.enabled ??
          true;
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

  /// return the TextStyle for a form field (TextField, ....)
  TextStyle get formFieldTextStyle {
    // MaterialSpec - titleMedium maps to FormField textStyle
    TextStyle textStyle =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    if (widget.controller is FormFieldController) {
      final formController = (widget.controller as FormFieldController);
      return textStyle.copyWith(
        fontSize: formController.labelStyle?.fontSize,
        overflow: formController.labelStyle?.overflow ?? TextOverflow.ellipsis,
        color: formController.labelStyle?.color,
        fontWeight: formController.labelStyle?.fontWeight,
        // TODO: expose color, ... for all form fields here
      );
    }
    return textStyle;
  }
}
