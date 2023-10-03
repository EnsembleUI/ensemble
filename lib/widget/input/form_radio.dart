import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:provider/provider.dart';

class EnsembleRadio extends RadioWidget {
  static const type = 'Radio';
  EnsembleRadio({super.key});
}

abstract class RadioWidget extends StatefulWidget
    with Invokable, HasController<RadioController, RadioState> {
  RadioWidget({Key? key}) : super(key: key);

  final RadioController _controller = RadioController();

  @override
  RadioController get controller => _controller;

  @override
  State<StatefulWidget> createState() => RadioState();

  @override
  Map<String, Function> getters() =>
      {'value': () => CustomRadioController(controller).groupValue};

  @override
  Map<String, Function> setters() => {
        'onChange': (definition) => controller.onChange =
            framework.EnsembleAction.fromYaml(definition, initiator: this),
        'groupId': (value) {
          var str = Utils.getString(value, fallback: "id1");
          controller.groupId = str;
        },
        'leadingTitle': (text) =>
            controller.leadingTitle = Utils.optionalString(text),
        'radioValue': (text) =>
            controller.radioValue = Utils.getString(text, fallback: "Radio1"),
      };

  @override
  Map<String, Function> methods() => {};
}

class RadioController extends FormFieldController {
  String groupId = "";
  String radioValue = "";
  String? leadingTitle;
  framework.EnsembleAction? onChange;
}

class RadioState extends FormFieldWidgetState<RadioWidget> {
  void onToggle(String groupValue, String groupId) {
    if (widget.controller.onChange != null) {
      ScreenController().executeAction(context, widget.controller.onChange!,
          event: EnsembleEvent(widget));
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    String titleText = widget.controller.leadingTitle == null
        ? widget.controller.radioValue
        : widget.controller.leadingTitle!;
    return InputWrapper(
        type: EnsembleRadio.type,
        widget: FormField<String>(
            key: validatorKey,
            validator: (value) {
              if (CustomRadioController(widget.controller)
                      .controller
                      .required &&
                  CustomRadioController(widget.controller).groupValue.isEmpty) {
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
                      errorText: field.errorText),
                  child: Row(
                    children: [
                      ChangeNotifierProvider(
                        create: (context) =>
                            CustomRadioController(widget.controller),
                        child: Consumer<CustomRadioController>(
                          builder: (context, ref, child) => Radio.adaptive(
                              value: widget.controller.radioValue,
                              groupValue: ref.groupValue,
                              onChanged: (String? value) => ref
                                  .setGroupValue(widget.controller.radioValue)),
                        ),
                      ),
                      Expanded(
                          child: Text(
                        titleText,
                        style: formFieldTextStyle,
                      ))
                    ],
                  ),
                )),
        controller: widget.controller);
  }
}

class CustomRadioController extends ChangeNotifier {
  static final Map<String, CustomRadioController> _cache = {};

  RadioController radioController;
  factory CustomRadioController(RadioController radioController) =>
      _cache.putIfAbsent(radioController.groupId,
          () => CustomRadioController._internal(radioController));

  CustomRadioController._internal(this.radioController)
      : controller = radioController;

  String groupValue = "";
  void setGroupValue(String value) {
    groupValue = value;
    notifyListeners();
  }

  RadioController controller;
}
