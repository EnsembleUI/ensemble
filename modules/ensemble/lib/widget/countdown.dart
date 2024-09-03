import 'dart:async';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

// Example of Countdown:
// Countdown:
//   id: myCountdown
//   date: "2023-10-27 00:02:00"
//   autoStart: false
//   showLabels: true
//   format: timeOnly
//   gap: 6
//   labelGap: 2
//   onStart: |
//     //@code
//     console.log("Start");
//   onComplete: |
//     //@code
//     console.log("Completed");
//   styles:
//     textStyle: { fontWeight: bold, fontSize: 24 }
//     labelStyle: { fontWeight: bold, color: 0xFF0BA182, fontSize: 16 }

// Example of calling methods:
// Button:
//   styles:
//     outline: true
//     borderColor: 0xffed5742
//     labelStyle:
//       color: 0xffed5742
//   label: Start Timer
//   onTap: |
//     //@code
//     myCountdown.start();

enum Formats { daysAndTime, daysOnly, timeOnly }

class Countdown extends StatefulWidget
    with Invokable, HasController<CountdownController, CountdownState> {
  static const type = 'Countdown';

  Countdown({Key? key}) : super(key: key);

  final CountdownController _controller = CountdownController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => CountdownState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      // Method to start the countdown
      'start': () => controller.countdownAction?.startTimer(),
      // Method to stop the countdown. Stopping the counter allows restarting it by using start() method
      'stop': () => controller.countdownAction?.stopTimer(),
      // Method to reset the countdown to the initial state
      'reset': () => controller.countdownAction?.resetTimer(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      // The date time for the countdown. It must be in future
      'date': (value) => _controller.date = Utils.getDate(value),
      // Horizontal gap between each widget
      'gap': (value) => _controller.gap = Utils.getInt(value, fallback: 4),
      // Vertical gap between the date/time value and its respective label
      'labelGap': (value) =>
          _controller.labelGap = Utils.getInt(value, fallback: 4),
      // Boolean to define whether it should start automatically
      'autoStart': (value) => _controller.autoStart = Utils.getBool(
            value,
            fallback: true,
          ),
      // Boolean to for showing labels or not
      'showLabels': (value) => _controller.showLabels = Utils.getBool(
            value,
            fallback: true,
          ),
      // Selecting the different formats to show
      'format': (value) => _controller.format = Formats.values.byName(
            Utils.getString(
              value,
              fallback: 'daysAndTime',
            ),
          ),
      // TextStyle for the Date/Time Text
      'textStyle': (style) =>
          _controller.textStyle = Utils.getTextStyleAsComposite(
            _controller,
            style: style,
          ),
      // TextStyle for the labels
      'labelStyle': (style) =>
          _controller.labelStyle = Utils.getTextStyleAsComposite(
            _controller,
            style: style,
          ),
      // Callback method for onStart
      'onStart': (definition) => _controller.onStart =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onComplete
      'onComplete': (definition) => _controller.onComplete =
          EnsembleAction.from(definition, initiator: this),
      // Callback method for onStop
      'onStop': (definition) =>
          _controller.onStop = EnsembleAction.from(definition, initiator: this),
      // Callback method for onReset
      'onReset': (definition) => _controller.onReset =
          EnsembleAction.from(definition, initiator: this),
    };
  }
}

class CountdownController extends WidgetController {
  DateTime? date;
  bool autoStart = true;
  bool showLabels = true;
  Formats format = Formats.daysAndTime;
  int gap = 4;
  int labelGap = 4;

  EnsembleAction? onStart;
  EnsembleAction? onComplete;
  EnsembleAction? onStop;
  EnsembleAction? onReset;

  CountdownAction? countdownAction;

  TextStyleComposite? _textStyle;

  TextStyleComposite get textStyle => _textStyle ??= TextStyleComposite(this);

  set textStyle(TextStyleComposite style) => _textStyle = style;

  TextStyleComposite? _labelStyle;

  TextStyleComposite get labelStyle => _labelStyle ??= TextStyleComposite(this);

  set labelStyle(TextStyleComposite style) => _labelStyle = style;
}

mixin CountdownAction on EWidgetState<Countdown> {
  void startTimer();

  void stopTimer();

  void resetTimer();
}

class CountdownState extends EWidgetState<Countdown> with CountdownAction {
  late DateTime _startingTime;
  late Duration _duration;

  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();

    _startingTime = DateTime.now();
    _duration = widget._controller.date!.difference(_startingTime);

    if (_duration.isNegative) {
      throw RuntimeError("Please enter dateTime in future");
    }

    if (widget._controller.autoStart) startTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    widget.controller.countdownAction = this;
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant Countdown oldWidget) {
    super.didUpdateWidget(oldWidget);

    widget.controller.countdownAction = this;
  }

  @override
  void startTimer() {
    WidgetsBinding.instance.addPostFrameCallback(
      (_) {
        if (widget._controller.onStart != null) {
          ScreenController().executeAction(
            context,
            widget._controller.onStart!,
            event: EnsembleEvent(widget),
          );
        }
      },
    );

    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setCountDown(),
    );
  }

  @override
  void stopTimer() {
    if (widget._controller.onStop != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onStop!,
        event: EnsembleEvent(widget, data: _duration.inSeconds),
      );
    }

    setState(() => _countdownTimer!.cancel());
  }

  @override
  void resetTimer() {
    if (widget._controller.onReset != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onReset!,
        event: EnsembleEvent(widget),
      );
    }

    stopTimer();
    setState(
      () => _duration = widget._controller.date!.difference(_startingTime),
    );
  }

  void setCountDown() {
    const reduceSecondsBy = 1;

    setState(() {
      final seconds = _duration.inSeconds - reduceSecondsBy;
      if (seconds < 0) {
        if (widget._controller.onComplete != null) {
          ScreenController().executeAction(
            context,
            widget._controller.onComplete!,
            event: EnsembleEvent(widget),
          );
        }

        _countdownTimer!.cancel();
      } else {
        _duration = Duration(seconds: seconds);
      }
    });
  }

  @override
  Widget buildWidget(BuildContext context) {
    final controller = widget._controller;

    String strDigits(int n) => n.toString().padLeft(2, '0');

    int totalHours = _duration.inHours.remainder(24);

    if (controller.format == Formats.timeOnly) {
      totalHours += 24 * _duration.inDays;
    }

    final days = strDigits(_duration.inDays);
    final hours = strDigits(totalHours);
    final minutes = strDigits(_duration.inMinutes.remainder(60));
    final seconds = strDigits(_duration.inSeconds.remainder(60));

    bool isDaysVisible = controller.format == Formats.daysAndTime ||
        controller.format == Formats.daysOnly;
    bool isTimeVisible = controller.format == Formats.daysAndTime ||
        controller.format == Formats.timeOnly;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (isDaysVisible) ...[
          TextTile(
            text: days,
            subTitle: 'Days',
            labelGap: controller.labelGap.toDouble(),
            textStyle: controller.textStyle.getTextStyle(),
            labelStyle: controller.labelStyle.getTextStyle(),
            isLabelVisible: controller.showLabels,
          ),
          SizedBox(width: controller.gap * 4),
        ],
        if (isTimeVisible) ...[
          TextTile(
            text: hours,
            subTitle: 'Hours',
            labelGap: controller.labelGap.toDouble(),
            textStyle: controller.textStyle.getTextStyle(),
            labelStyle: controller.labelStyle.getTextStyle(),
            isLabelVisible: controller.showLabels,
          ),
          SizedBox(width: controller.gap.toDouble()),
          Text(':', style: controller.textStyle.getTextStyle()),
          SizedBox(width: controller.gap.toDouble()),
          TextTile(
            text: minutes,
            subTitle: 'Minutes',
            labelGap: controller.labelGap.toDouble(),
            textStyle: controller.textStyle.getTextStyle(),
            labelStyle: controller.labelStyle.getTextStyle(),
            isLabelVisible: controller.showLabels,
          ),
          SizedBox(width: controller.gap.toDouble()),
          Text(':', style: controller.textStyle.getTextStyle()),
          SizedBox(width: controller.gap.toDouble()),
          TextTile(
            text: seconds,
            subTitle: 'Seconds',
            labelGap: controller.labelGap.toDouble(),
            textStyle: controller.textStyle.getTextStyle(),
            labelStyle: controller.labelStyle.getTextStyle(),
            isLabelVisible: controller.showLabels,
          ),
        ]
      ],
    );
  }
}

class TextTile extends StatelessWidget {
  const TextTile({
    super.key,
    required this.text,
    required this.subTitle,
    required this.textStyle,
    required this.labelStyle,
    required this.isLabelVisible,
    required this.labelGap,
  });

  final String text;
  final String subTitle;
  final TextStyle textStyle;
  final TextStyle labelStyle;
  final bool isLabelVisible;
  final double labelGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(text, style: textStyle),
        SizedBox(height: labelGap),
        Visibility(
          visible: isLabelVisible,
          child: Text(subTitle, style: labelStyle),
        ),
      ],
    );
  }
}
