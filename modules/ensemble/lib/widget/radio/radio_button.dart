import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/radio/radio_button_controller.dart';
import 'package:ensemble/widget/radio/styled_radio.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/**
 * Individual Radio buttons scattered across the screens and group together by groupId
 * See also: RadioGroup
 */
class RadioButton extends StatefulWidget
    with Invokable, HasController<RadioController, RadioState> {
  RadioButton({Key? key}) : super(key: key);
  static const type = 'RadioButton';

  final RadioController _controller = RadioController();

  @override
  RadioController get controller => _controller;

  @override
  State<StatefulWidget> createState() => RadioState();

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> setters() => {
        'value': (value) => controller.value = value,
        'groupId': (value) => controller.groupId =
            Utils.getString(value, fallback: controller.groupId),
        'selected': (value) => controller.selected = Utils.optionalBool(value),
        'size': (value) => _controller.size = Utils.optionalInt(value, min: 0),
        'activeColor': (color) =>
            _controller.activeColor = Utils.getColor(color),
        'inactiveColor': (color) =>
            _controller.inactiveColor = Utils.getColor(color),
      };

  @override
  Map<String, Function> methods() => {};
}

class RadioController extends FormFieldController {
  dynamic value;
  String groupId = "";
  bool? selected;

  Color? activeColor;
  Color? inactiveColor;
  int? size;
}

class RadioState extends FormFieldWidgetState<RadioButton> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget.controller.groupId == "") {
      throw LanguageError("${RadioButton.type} requires a groupId.");
    }
    if (scopeManager == null) {
      throw LanguageError("Invalid ScopeManager for ${RadioButton.type}");
    }
    var radioButtonController = RadioButtonController.getInstance(
        widget.controller.groupId, scopeManager!);
    // set default value if selected
    if (widget._controller.selected == true) {
      radioButtonController.defaultValue = widget._controller.value;
    }

    return InputWrapper(
      type: RadioButton.type,
      widget: FormField<String>(
        key: validatorKey,
        validator: (value) {
          if (widget.controller.required &&
              radioButtonController.selectedValue == null) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<String> field) => InputDecorator(
          decoration: inputDecoration.copyWith(
            contentPadding: EdgeInsets.zero,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            errorText: field.errorText,
          ),
          child: ChangeNotifierProvider(
            create: (context) => radioButtonController,
            child: Consumer<RadioButtonController>(
              builder: (context, ref, child) => StyledRadio(
                value: widget.controller.value,
                groupValue: ref.selectedValue,
                onChanged: (value) => ref.selectedValue = value,
                activeColor: widget._controller.activeColor,
                inactiveColor: widget._controller.inactiveColor,
              ),
            ),
          ),
        ),
      ),
      controller: widget.controller,
    );
  }
}
