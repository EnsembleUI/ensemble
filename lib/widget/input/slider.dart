import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/screen_controller.dart';

class EnsembleSlider extends StatefulWidget
    with Invokable, HasController<SliderController, SliderState> {
  static const type = 'Slider';

  EnsembleSlider({Key? key}) : super(key: key);

  final SliderController _controller = SliderController();
  @override
  SliderController get controller => _controller;

  @override
  State<StatefulWidget> createState() => SliderState();

  @override
  Map<String, Function> getters() {
    return {
      'value': () => _controller.value,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'getValue': () => _controller.value.round(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'initialValue': (value) =>
          _controller.value = Utils.optionalDouble(value) ?? 0,
      'min': (value) => _controller.minValue = Utils.optionalDouble(value) ?? 0,
      'max': (value) =>
          _controller.maxValue = Utils.optionalDouble(value) ?? 100,
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.fromYaml(definition, initiator: this),
      'divisions': (value) => _controller.divisions = Utils.optionalInt(value),
    };
  }
}

class SliderController extends FormFieldController {
  double value = 0.0;
  double minValue = 0.0;
  double maxValue = 100.0;
  int? divisions;
  EnsembleAction? onChange;
}

class SliderState extends FormFieldWidgetState<EnsembleSlider> {
  @override
  Widget buildWidget(BuildContext context) {
    return InputWrapper(
      type: EnsembleSlider.type,
      controller: widget.controller,
      widget: FormField<double>(
        key: validatorKey,
        validator: (value) {
          // You can add validation logic here.
          return null;
        },
        builder: (FormFieldState<double> field) {
          return SliderWidget(
            min: widget._controller.minValue,
            max: widget._controller.maxValue,
            value: widget._controller.value,
            divisions: widget._controller.divisions,
            onChanged: isEnabled()
                ? (value) {
                    setState(() {
                      widget._controller.value = value;
                    });
                    if (widget._controller.onChange != null) {
                      ScreenController().executeAction(
                        context,
                        widget._controller.onChange!,
                        event: EnsembleEvent(widget),
                      );
                    }
                  }
                : null,
          );
        },
      ),
    );
  }
}

class SliderWidget extends StatelessWidget {
  final double min;
  final double max;
  final double value;
  final int? divisions;
  final ValueChanged<double>? onChanged;

  const SliderWidget({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    this.onChanged,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        valueIndicatorShape: const PaddleSliderValueIndicatorShape(),
        showValueIndicator: ShowValueIndicator.always,
        valueIndicatorTextStyle: const TextStyle(
          color: Colors.white,
        ),
      ),
      child: Slider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
        label: value.round().toString(),
        divisions: divisions,
      ),
    );
  }
}
