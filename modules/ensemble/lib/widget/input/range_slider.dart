import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleRangeSlider extends StatefulWidget
    with Invokable, HasController<RangeSliderController, SliderState> {
  static const type = 'RangeSlider';

  EnsembleRangeSlider({Key? key}) : super(key: key);

  final RangeSliderController _controller = RangeSliderController();
  @override
  RangeSliderController get controller => _controller;

  @override
  State<StatefulWidget> createState() => SliderState();

  @override
  Map<String, Function> getters() {
    return {
      'values': () => _controller.values,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'initialValues': (value) => _controller.values =
          Utils.getRangeValues(value) ?? const RangeValues(0, 1.0),
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

class RangeSliderController extends FormFieldController {
  RangeValues values = const RangeValues(0.0, 1.0);
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

class SliderState extends FormFieldWidgetState<EnsembleRangeSlider> {
  @override
  Widget buildWidget(BuildContext context) {
    final int decimalPlaces = calculateDecimalPlaces(widget.controller.minValue,
        widget.controller.maxValue, widget.controller.divisions);

    return InputWrapper(
      type: EnsembleRangeSlider.type,
      controller: widget.controller,
      widget: FormField<RangeValues>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required &&
              widget.controller.values.start == widget.controller.minValue &&
              widget.controller.values.end == widget.controller.minValue) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<RangeValues> field) {
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
            child: RangeSlider(
              labels: RangeLabels(
                widget.controller.values.start.toStringAsFixed(decimalPlaces),
                widget.controller.values.end.toStringAsFixed(decimalPlaces),
              ),
              min: widget.controller.minValue,
              max: widget.controller.maxValue,
              values: widget.controller.values,
              divisions: widget.controller.divisions,
              onChanged: isEnabled()
                  ? (values) {
                      setState(() {
                        widget.controller.values = values;
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
