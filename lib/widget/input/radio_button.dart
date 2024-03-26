import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class RadioWidget extends StatefulWidget
    with Invokable, HasController<RadioController, RadioState> {
  RadioWidget({Key? key}) : super(key: key);
  static const type = 'RadioButton';

  final RadioController _controller = RadioController();

  @override
  RadioController get controller => _controller;

  @override
  State<StatefulWidget> createState() => RadioState();

  @override
  Map<String, Function> getters() => {
        'value': () => CustomRadioController(controller).selectedValue,
      };

  @override
  Map<String, Function> setters() => {
        'groupId': (value) =>
            controller.groupId = Utils.getString(value, fallback: "id1"),
        'title': (text) => controller.title = Utils.optionalString(text),
        'activeColor': (value) =>
            controller.activeColor = Utils.getColor(value),
        'horizontalSpace': (value) =>
            controller.horizontalSpace = Utils.getDouble(value, fallback: 10),
        'value': (text) =>
            controller.value = Utils.getString(text, fallback: "Radio1"),
      };

  @override
  Map<String, Function> methods() => {
        'select': (value) {
          CustomRadioController(controller)
              .setGroupValue(Utils.optionalString(value) ?? '');
        },
      };
}

class RadioController extends FormFieldController {
  String groupId = "";
  String value = "";
  String? title;
  double horizontalSpace = 10;
  Color? activeColor;
}

class RadioState extends FormFieldWidgetState<RadioWidget> {
  @override
  Widget buildWidget(BuildContext context) {
    String titleText = widget.controller.title == null
        ? widget.controller.value
        : widget.controller.title!;
    return InputWrapper(
      type: RadioWidget.type,
      widget: FormField<String>(
        key: validatorKey,
        validator: (value) {
          if (CustomRadioController(widget.controller).controller.required &&
              CustomRadioController(widget.controller).selectedValue.isEmpty) {
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
          child: Row(
            children: [
              ChangeNotifierProvider(
                create: (context) => CustomRadioController(widget.controller),
                child: Consumer<CustomRadioController>(
                  builder: (context, ref, child) => Radio.adaptive(
                    value: widget.controller.value,
                    activeColor: widget.controller.activeColor,
                    groupValue: ref.selectedValue,
                    onChanged: (String? value) => ref.setGroupValue(
                      widget.controller.value,
                    ),
                  ),
                ),
              ),
              SizedBox(width: widget.controller.horizontalSpace),
              Expanded(
                child: Text(
                  titleText,
                  style: formFieldTextStyle,
                ),
              )
            ],
          ),
        ),
      ),
      controller: widget.controller,
    );
  }
}

class CustomRadioController extends ChangeNotifier {
  static final Map<String, CustomRadioController> _cache = {};

  final RadioController controller;
  String selectedValue = "";

  factory CustomRadioController(RadioController radioController) =>
      _cache.putIfAbsent(
        radioController.groupId,
        () => CustomRadioController._internal(radioController),
      );

  CustomRadioController._internal(this.controller);

  void setGroupValue(String value) {
    selectedValue = value;
    notifyListeners();
  }
}
