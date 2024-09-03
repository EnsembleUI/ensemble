import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
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
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'initialValue': (value) =>
          _controller.value = Utils.optionalDouble(value) ?? 0,
      'min': (value) =>
          _controller.minValue = Utils.getDouble(value, fallback: 0.0),
      'max': (value) =>
          _controller.maxValue = Utils.getDouble(value, fallback: 1.0),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'divisions': (value) => _controller.divisions = Utils.optionalInt(value),
      'thumbColor': (value) => _controller.thumbColor = Utils.getColor(value),
      'inactiveTrackColor': (value) =>
          _controller.inactiveTrackColor = Utils.getColor(value),
      'activeTrackColor': (value) =>
          _controller.activeTrackColor = Utils.getColor(value),
      'activeTickMarkColor': (value) =>
          _controller.activeTickMarkColor = Utils.getColor(value),
      'inactiveTickMarkColor': (value) =>
          _controller.inactiveTickMarkColor = Utils.getColor(value),
      'trackHeight': (value) =>
          _controller.trackHeight = Utils.optionalDouble(value),
      'thumbRadius': (value) =>
          _controller.thumbRadius = Utils.getDouble(value, fallback: 10),
    };
  }
}

class SliderController extends FormFieldController {
  double value = 0.0;
  double minValue = 0.0;
  double maxValue = 1.0;
  int? divisions;
  EnsembleAction? onChange;

  Color? thumbColor;
  Color? inactiveTrackColor;
  Color? activeTrackColor;
  Color? activeTickMarkColor;
  Color? inactiveTickMarkColor;

  double? trackHeight;
  double thumbRadius = 10;
}

int calculateDecimalPlaces(double min, double max, int? divisions) {
  if (divisions == null) return 1;
  double interval = (max - min) / divisions;

  int decimalPlaces = 1;
  while ((interval *= 10) < 1) {
    decimalPlaces++;
  }

  return decimalPlaces;
}

class SliderState extends FormFieldWidgetState<EnsembleSlider> {
  @override
  Widget buildWidget(BuildContext context) {
    int decimalPlaces = calculateDecimalPlaces(widget.controller.minValue,
        widget.controller.maxValue, widget.controller.divisions);

    return InputWrapper(
      type: EnsembleSlider.type,
      controller: widget.controller,
      widget: FormField<double>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required &&
              widget.controller.value == widget.controller.minValue) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<double> field) {
          return SliderTheme(
            data: SliderTheme.of(context).copyWith(
              thumbColor: widget.controller.thumbColor,
              inactiveTrackColor: widget.controller.inactiveTrackColor,
              activeTrackColor: widget.controller.activeTrackColor,
              activeTickMarkColor: widget.controller.activeTickMarkColor,
              inactiveTickMarkColor: widget.controller.inactiveTickMarkColor,
              thumbShape: RoundSliderThumbShape(
                enabledThumbRadius: widget._controller.thumbRadius,
              ),
              trackHeight: widget.controller.trackHeight,
              valueIndicatorColor: widget.controller.thumbColor,
            ),
            child: Slider(
              label: widget.controller.value.toStringAsFixed(decimalPlaces),
              min: widget.controller.minValue,
              max: widget.controller.maxValue,
              value: widget.controller.value,
              divisions: widget.controller.divisions,
              onChanged: isEnabled()
                  ? (value) {
                      setState(() {
                        widget.controller.value = value;
                      });
                      if (widget.controller.onChange != null) {
                        ScreenController().executeAction(
                          context,
                          widget.controller.onChange!,
                          event: EnsembleEvent(widget),
                        );
                      }
                    }
                  : null,
            ),
          );
        },
      ),
    );
  }
}
