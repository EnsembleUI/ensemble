import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleCheckbox extends StatefulWidget
    with Invokable, HasController<CheckboxController, CheckboxState> {
  static const type = 'Checkbox';

  EnsembleCheckbox({Key? key}) : super(key: key);

  final CheckboxController _controller = CheckboxController();

  @override
  CheckboxController get controller => _controller;

  @override
  State<StatefulWidget> createState() => CheckboxState();

  @override
  Map<String, Function> getters() {
    return {'value': () => _controller.value};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) =>
          _controller.value = Utils.getBool(value, fallback: false),
      'leadingText': (text) =>
          _controller.leadingText = Utils.optionalString(text),
      'trailingText': (text) =>
          _controller.trailingText = Utils.optionalString(text),
      'size': (value) => _controller.size = Utils.optionalInt(value, min: 0),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this),

      // deprecated - for backward compatible
      'selectedColor': (color) =>
          _controller.selectedColor = Utils.getColor(color),
      'unSelectedColor': (color) =>
          _controller.unSelectedColor = Utils.getColor(color),

      // borderColor/fillColor is on super controller
      'activeColor': (color) => _controller.activeColor = Utils.getColor(color),
      'checkColor': (color) => _controller.checkColor = Utils.getColor(color),
    };
  }

  void onToggle(bool newValue) {
    setProperty('value', newValue);
  }
}

class CheckboxController extends FormFieldController {
  int? size;

  bool value = false;
  String? leadingText;
  String? trailingText;
  Color? checkColor;

  // the color when the checkbox is selected
  Color? activeColor;
  @Deprecated("use activeColor instead")
  Color? selectedColor;

  @Deprecated("use borderColor instead")
  Color? unSelectedColor;

  framework.EnsembleAction? onChange;
}

class CheckboxState extends FormFieldWidgetState<EnsembleCheckbox> {
  void onToggle(bool newValue) {
    widget.onToggle(newValue);
    //validatorKey.currentState!.validate();

    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget));
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    // add leading/trailing text + the actual widget
    List<Widget> children = [];
    if (widget._controller.leadingText != null) {
      children.add(Flexible(
          child: Text(
        widget._controller.leadingText!,
        style: formFieldTextStyle,
      )));
    }

    children.add(buildCheckbox(context));

    if (widget._controller.trailingText != null) {
      children.add(Expanded(
          child: Text(
        widget._controller.trailingText!,
        style: formFieldTextStyle,
      )));
    }

    // wraps around FormField to get all the form effects
    return InputWrapper(
      type: EnsembleCheckbox.type,
      controller: widget._controller,
      widget: FormField<bool>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required && !widget._controller.value) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<bool> field) {
          return InputDecorator(
            decoration: inputDecoration.copyWith(
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorText: field.errorText),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.start, children: children),
          );
        },
      ),
    );
  }

  Widget buildCheckbox(BuildContext context) {
    var theme = Theme.of(context);
    int borderWidth = widget._controller.borderWidth ??
        theme.checkboxTheme.side?.width.toInt() ??
        2;
    Color borderColor = widget._controller.borderColor ??
        widget._controller.unSelectedColor ??
        theme.checkboxTheme.side?.color ??
        ThemeManager().getBorderColor(context);
    Color? activeColor =
        widget._controller.activeColor ?? widget._controller.selectedColor;

    Widget checkbox = Checkbox(
        side: MaterialStateBorderSide.resolveWith((states) {
          if (!states.contains(MaterialState.selected) &&
              !states.contains(MaterialState.disabled) &&
              !states.contains(MaterialState.error)) {
            return BorderSide(
                width: borderWidth.toDouble(), color: borderColor);
          }
          // fallback to theme, which fallback to default
          return null;
        }),
        shape: widget._controller.borderRadius == null
            ? null
            : RoundedRectangleBorder(
                borderRadius: widget._controller.borderRadius!.getValue(),
                side: BorderSide(
                    width: borderWidth.toDouble(), color: borderColor)),
        activeColor: activeColor,
        checkColor: widget._controller.checkColor,
        fillColor: MaterialStateProperty.resolveWith<Color?>(
            (Set<MaterialState> states) {
          // show the fillColor when not in any states
          if (widget._controller.fillColor != null && states.isEmpty) {
            return widget._controller.fillColor;
          }
          return null;
        }),
        value: widget._controller.value,
        onChanged:
            isEnabled() ? (bool? value) => onToggle(value ?? false) : null);

    // if the size is specified and different than the default size, need to scale it
    if (widget._controller.size != null || theme.checkboxTheme.size != null) {
      int newSize = (widget._controller.size ?? theme.checkboxTheme.size)!;
      if (newSize != Checkbox.width.toInt()) {
        checkbox = Transform.scale(
          scale: newSize / Checkbox.width,
          child: checkbox,
        );
      }
    }
    return checkbox;
  }
}
