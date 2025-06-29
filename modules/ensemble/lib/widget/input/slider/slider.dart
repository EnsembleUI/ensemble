import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble/util/utils.dart';
import 'composites/track_style.dart';
import 'composites/tick_mark_style.dart';
import 'composites/thumb_style.dart';
import 'composites/overlay_style.dart';
import 'composites/value_indicator_style.dart';
import 'slider_controller.dart';
import 'slider_state.dart';

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
      'min': () => _controller.minValue,
      'max': () => _controller.maxValue,
      'startValue': () => _controller.startValue,
      'endValue': () => _controller.endValue,
      'enableRange': () => _controller.enableRange,
      'trackStyle': () => _controller.trackStyle,
      'tickMarkStyle': () => _controller.tickMarkStyle,
      'thumbStyle': () => _controller.thumbStyle,
      'overlayStyle': () => _controller.overlayStyle,
      'valueIndicatorStyle': () => _controller.valueIndicatorStyle,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'enableRange': (value) => _controller.enableRange = Utils.getBool(value, fallback: false),
      'startValue': (value) => _controller.startValue = Utils.getDouble(value, fallback: 0.0),
      'endValue': (value) => _controller.endValue = Utils.getDouble(value, fallback: 1.0),
      // Basic Properties
      'initialValue': (value) =>
          _controller.value = Utils.optionalDouble(value) ?? 0,
      'min': (value) =>
          _controller.minValue = Utils.getDouble(value, fallback: 0.0),
      'max': (value) =>
          _controller.maxValue = Utils.getDouble(value, fallback: 1.0),
      'divisions': (value) => _controller.divisions = Utils.optionalInt(value),

      // Style Composites
      'trackStyle': (value) =>
          _controller.trackStyle = TrackStyleComposite.from(_controller, value),
      'tickMarkStyle': (value) => _controller.tickMarkStyle =
          TickMarkStyleComposite.from(_controller, value),
      'thumbStyle': (value) => _controller.thumbStyle = 
          ThumbStyleComposite.from(_controller, value),
      'overlayStyle': (value) => _controller.overlayStyle = 
          OverlayStyleComposite.from(_controller, value),
      'valueIndicatorStyle': (value) => _controller.valueIndicatorStyle = 
          ValueIndicatorStyleComposite.from(_controller, value),

      // @deprecated properties
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

      // Event Handler
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'onChangeStart': (definition) => _controller.onChangeStart =
        EnsembleAction.from(definition, initiator: this),
      'onChangeEnd': (definition) => _controller.onChangeEnd =
          EnsembleAction.from(definition, initiator: this),
    };
  }
}