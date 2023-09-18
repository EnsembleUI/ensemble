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
            fullWidth: true,
          );
        },
      ),
    );
  }
}

class SliderWidget extends StatefulWidget {
  final double min;
  final double max;
  final double value;
  final int? divisions;
  final ValueChanged<double>? onChanged;
  final double sliderHeight;
  final bool fullWidth;

  const SliderWidget({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    this.onChanged,
    this.divisions,
    this.sliderHeight = 48,
    required this.fullWidth,
  });

  @override
  State<SliderWidget> createState() => _SliderWidgetState();
}

class _SliderWidgetState extends State<SliderWidget> {
  @override
  Widget build(BuildContext context) {
    double paddingFactor = .2;

    if (widget.fullWidth) paddingFactor = .3;

    return SizedBox(
      width: widget.fullWidth ? double.infinity : (widget.sliderHeight) * 5.5,
      height: (widget.sliderHeight),
      child: Padding(
        padding: EdgeInsets.fromLTRB(widget.sliderHeight * paddingFactor, 2,
            widget.sliderHeight * paddingFactor, 2),
        child: Row(
          children: <Widget>[
            Text(
              '${widget.min}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.sliderHeight * .3,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            SizedBox(
              width: widget.sliderHeight * .1,
            ),
            Expanded(
              child: Center(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.white.withOpacity(1),
                    inactiveTrackColor: Colors.white.withOpacity(.5),
                    trackHeight: 4.0,
                    thumbShape: CustomSliderThumbRect(
                      thumbRadius: widget.sliderHeight * .4,
                      min: widget.min.toInt(),
                      max: widget.max.toInt(),
                      thumbHeight: 80,
                    ),
                    overlayColor: Colors.white.withOpacity(.4),
                    activeTickMarkColor: Colors.white,
                    inactiveTickMarkColor: Colors.red.withOpacity(.7),
                  ),
                  child: Slider(
                    value: widget.value,
                    min: widget.min,
                    max: widget.max,
                    onChanged: widget.onChanged,
                    label: widget.value.round().toString(),
                    divisions: widget.divisions,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: widget.sliderHeight * .1,
            ),
            Text(
              '${widget.max}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: widget.sliderHeight * .3,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CustomSliderThumbRect extends SliderComponentShape {
  final double thumbRadius;
  final double thumbHeight;
  final int min;
  final int max;

  const CustomSliderThumbRect({
    required this.thumbRadius,
    required this.thumbHeight,
    required this.min,
    required this.max,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final Canvas canvas = context.canvas;

    final rRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: center, width: thumbHeight * 1.2, height: thumbHeight * .6),
      Radius.circular(thumbRadius * .4),
    );

    final paint = Paint()
      ..color = sliderTheme.activeTrackColor!
      ..style = PaintingStyle.fill;

    TextSpan span = TextSpan(
        style: TextStyle(
            fontSize: thumbHeight * .3,
            fontWeight: FontWeight.w700,
            color: sliderTheme.thumbColor,
            height: 1),
        text: getValue(value));
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();
    Offset textCenter =
        Offset(center.dx - (tp.width / 2), center.dy - (tp.height / 2));

    canvas.drawRRect(rRect, paint);
    tp.paint(canvas, textCenter);
  }

  String getValue(double value) {
    return (min + (max - min) * value).round().toString();
  }
}
