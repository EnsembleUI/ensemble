import 'package:flutter/material.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble/util/utils.dart';
import 'slider.dart';

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
          if (widget.controller.required) {
            if (widget.controller.enableRange) {
              if (widget.controller.startValue == widget.controller.minValue &&
                  widget.controller.endValue == widget.controller.minValue) {
                return Utils.translateWithFallback(
                    'ensemble.input.required', 'This field is required');
              }
            } else if (widget.controller.value == widget.controller.minValue) {
              return Utils.translateWithFallback(
                  'ensemble.input.required', 'This field is required');
            }
          }
          return null;
        },
        builder: (FormFieldState<double> field) {
          SliderThemeData themeData = SliderTheme.of(context).copyWith(
            // Track Colors
            trackShape: widget.controller.trackStyle.getTrackShape(),
            trackHeight: widget.controller.trackHeight ??
                widget.controller.trackStyle.trackHeight,
            activeTrackColor: widget.controller.activeTrackColor ??
                widget.controller.trackStyle.activeTrackColor,
            inactiveTrackColor: widget.controller.inactiveTrackColor ??
                widget.controller.trackStyle.inactiveTrackColor,
            secondaryActiveTrackColor:
                widget.controller.trackStyle.secondaryActiveTrackColor,
            disabledActiveTrackColor:
                widget.controller.trackStyle.disabledActiveTrackColor,
            disabledInactiveTrackColor:
                widget.controller.trackStyle.disabledInactiveTrackColor,
            disabledSecondaryActiveTrackColor:
                widget.controller.trackStyle.disabledSecondaryActiveTrackColor,

            // Tick Mark Colors
            tickMarkShape: widget.controller.tickMarkStyle.getTickMarkShape(
                widget.controller.trackHeight ??
                    widget.controller.trackStyle.trackHeight ??
                    2.0),
            activeTickMarkColor: widget.controller.activeTickMarkColor ??
                widget.controller.tickMarkStyle.activeColor,
            inactiveTickMarkColor: widget.controller.inactiveTickMarkColor ??
                widget.controller.tickMarkStyle.inactiveColor,
            disabledActiveTickMarkColor:
                widget.controller.tickMarkStyle.disabledActiveColor,
            disabledInactiveTickMarkColor:
                widget.controller.tickMarkStyle.disabledInactiveColor,

            // Thumb Properties
            thumbShape: widget.controller.thumbStyle.getThumbShape(),
            thumbColor: widget.controller.thumbColor ??
                widget.controller.thumbStyle.thumbColor,
            disabledThumbColor: widget.controller.thumbStyle.disabledThumbColor,

            // Overlay Properties
            overlayShape: widget.controller.overlayStyle.getOverlayShape(),
            overlayColor: widget.controller.overlayStyle.getOverlayColor(),

            // Value Indicator Properties
            showValueIndicator:
                widget.controller.valueIndicatorStyle.visibility,
            valueIndicatorColor: widget.controller.valueIndicatorStyle.color ??
                widget.controller.thumbColor ??
                widget.controller.thumbStyle.thumbColor,
            valueIndicatorTextStyle:
                widget.controller.valueIndicatorStyle.textStyle,
            valueIndicatorShape:
                widget.controller.valueIndicatorStyle.getIndicatorShape(),
          );

          return SliderTheme(
            data: themeData,
            child: widget.controller.enableRange
                ? _buildRangeSlider(context, decimalPlaces)
                : _buildSlider(context, decimalPlaces)
          );
        },
      ),
    );
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

  Widget _buildRangeSlider(BuildContext context, int decimalPlaces) {
    return RangeSlider(
      values:
          RangeValues(widget.controller.startValue, widget.controller.endValue),
      min: widget.controller.minValue,
      max: widget.controller.maxValue,
      divisions: widget.controller.divisions,
      labels: RangeLabels(
        widget.controller.startValue.toStringAsFixed(decimalPlaces),
        widget.controller.endValue.toStringAsFixed(decimalPlaces),
      ),
      onChanged: isEnabled()
          ? (RangeValues values) {
              setState(() {
                widget.controller.startValue = values.start;
                widget.controller.endValue = values.end;
              });
              if (widget.controller.onChange != null) {
                ScreenController().executeAction(
                  context,
                  widget.controller.onChange!,
                  event: EnsembleEvent(widget, data: {
                    'startValue': widget.controller.startValue,
                    'endValue': widget.controller.endValue
                  }),
                );
              }
            }
          : null,
    );
  }

  Widget _buildSlider(BuildContext context, int decimalPlaces) {
    return Slider(
      value: widget.controller.value,
      min: widget.controller.minValue,
      max: widget.controller.maxValue,
      divisions: widget.controller.divisions,
      label: widget.controller.value.toStringAsFixed(decimalPlaces),
      onChanged: isEnabled()
          ? (value) {
              setState(() {
                widget.controller.value = value;
              });
              if (widget.controller.onChange != null) {
                ScreenController().executeAction(
                  context,
                  widget.controller.onChange!,
                  event: EnsembleEvent(widget,
                      data: {'value': widget.controller.value}),
                );
              }
            }
          : null,
    );
  }
}


            // event: EnsembleEvent(null, data: {'user': currentUser}));
