import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class InlineTimePicker extends EnsembleWidget<InlineTimePickerController> {
  static const type = 'InlineTimePicker';

  const InlineTimePicker._(super.controller, {super.key});

  factory InlineTimePicker.build(dynamic controller) =>
      InlineTimePicker._(controller is InlineTimePickerController
          ? controller
          : InlineTimePickerController());

  @override
  State<StatefulWidget> createState() => InlineTimePickerState();
}

class InlineTimePickerController extends EnsembleBoxController {
  TimeOfDay? initialTime;
  TimeOfDay? selectedTime;
  int selectedSeconds = 0; // To hold the selected seconds
  EnsembleAction? onTimeChangedAction;
  CupertinoTimerPickerMode mode = CupertinoTimerPickerMode.hm;
  int? minuteInterval;
  int? secondInterval;
  String? onTimeChangedHaptic;

  /// Resets the time picker to the initial time.
  void reset() {
    selectedTime = initialTime;
    selectedSeconds = 0;
  }

  /// Returns the selected time formatted as a string without requiring context.
  String selectedTimeFormatted() {
    if (selectedTime == null) {
      return '';
    }

    final now = DateTime.now();
    final formattedTime = DateFormat('hh:mm:ss a').format(DateTime(
      now.year,
      now.month,
      now.day,
      selectedTime!.hour,
      selectedTime!.minute,
      selectedSeconds,
    ));

    return formattedTime;
  }

  @override
  Map<String, Function> getters() {
    return {
      'selectedTime': () => selectedTimeFormatted(),
    };
  }

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'initialTime': (time) => initialTime = Utils.getTimeOfDay(time),
      'onTimeChanged': (funcDefinition) => onTimeChangedAction =
          EnsembleAction.from(funcDefinition, initiator: this),
      'mode': (value) => mode = Utils.getEnum<CupertinoTimerPickerMode>(
          value, CupertinoTimerPickerMode.values),
      'minuteInterval': (value) => minuteInterval = Utils.optionalInt(value),
      'secondInterval': (value) => secondInterval = Utils.optionalInt(value),
      'onTimeChangedHaptic': (value) =>
          onTimeChangedHaptic = Utils.optionalString(value),
    });
}

class InlineTimePickerState extends EnsembleWidgetState<InlineTimePicker> {
  @override
  void initState() {
    super.initState();
    widget.controller.selectedTime =
        widget.controller.initialTime ?? TimeOfDay.now();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return EnsembleBoxWrapper(
      boxController: widget.controller,
      widget: CupertinoTimerPicker(
        mode: widget.controller.mode,
        initialTimerDuration: Duration(
          hours: widget.controller.selectedTime?.hour ?? TimeOfDay.now().hour,
          minutes:
              widget.controller.selectedTime?.minute ?? TimeOfDay.now().minute,
          seconds: widget
              .controller.selectedSeconds, // Initialize with selected seconds
        ),
        onTimerDurationChanged: (Duration newDuration) {
          onTimerDurationChanged(context, newDuration);
        },
        minuteInterval: widget.controller.minuteInterval ?? 1,
        secondInterval: widget.controller.secondInterval ?? 1,
      ),
    );
  }

  void onTimerDurationChanged(BuildContext context, Duration newDuration) {
    setState(() {
      widget.controller.selectedTime = TimeOfDay(
        hour: newDuration.inHours,
        minute: newDuration.inMinutes % 60,
      );
      widget.controller.selectedSeconds = newDuration.inSeconds % 60;
    });

    if (widget.controller.onTimeChangedHaptic != null) {
      ScreenController().executeAction(
        context,
        HapticAction(
            type: widget.controller.onTimeChangedHaptic!, onComplete: null),
      );
    }

    if (widget.controller.onTimeChangedAction != null) {
      ScreenController().executeAction(
        context,
        widget.controller.onTimeChangedAction!,
        event: EnsembleEvent(widget.controller),
      );
    }
  }
}
