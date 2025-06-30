import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'composites/track_style.dart';
import 'composites/tick_mark_style.dart';
import 'composites/thumb_style.dart';
import 'composites/overlay_style.dart';
import 'composites/value_indicator_style.dart';

class SliderController extends FormFieldController {
 // Range slider specific properties
  bool enableRange = false;
  double startValue = 0.0;
  double endValue = 1.0;
  // Basic Values
  double value = 0.0;
  double minValue = 0.0;
  double maxValue = 1.0;
  int? divisions;

  // Style Composites with lazy initialization
  TrackStyleComposite? _trackStyle;
  TrackStyleComposite get trackStyle =>
      _trackStyle ??= TrackStyleComposite(this);
  set trackStyle(TrackStyleComposite value) => _trackStyle = value;

  TickMarkStyleComposite? _tickMarkStyle;
  TickMarkStyleComposite get tickMarkStyle =>
      _tickMarkStyle ??= TickMarkStyleComposite(this);
  set tickMarkStyle(TickMarkStyleComposite value) => _tickMarkStyle = value;

  ThumbStyleComposite? _thumbStyle;
  ThumbStyleComposite get thumbStyle => 
      _thumbStyle ??= ThumbStyleComposite(this);
  set thumbStyle(ThumbStyleComposite value) => _thumbStyle = value;

  OverlayStyleComposite? _overlayStyle;
  OverlayStyleComposite get overlayStyle =>
      _overlayStyle ??= OverlayStyleComposite(this);
  set overlayStyle(OverlayStyleComposite value) => _overlayStyle = value;

  ValueIndicatorStyleComposite? _valueIndicatorStyle;
  ValueIndicatorStyleComposite get valueIndicatorStyle =>
      _valueIndicatorStyle ??= ValueIndicatorStyleComposite(this);
  set valueIndicatorStyle(ValueIndicatorStyleComposite value) => 
      _valueIndicatorStyle = value;

  // @deprecated. backward compatibility
  Color? thumbColor;
  Color? inactiveTrackColor;
  Color? activeTrackColor;
  Color? activeTickMarkColor;
  Color? inactiveTickMarkColor;
  double? trackHeight;
  double thumbRadius = 10;

  // Event Handler
  EnsembleAction? onChange;
  EnsembleAction? onChangeStart;
  EnsembleAction? onChangeEnd;
}