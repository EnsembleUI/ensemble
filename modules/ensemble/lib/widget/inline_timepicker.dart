import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart' as ensemble;
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/action/haptic_action.dart';
import 'package:intl/intl.dart'; // For date formatting
import '../framework/event.dart';

/// An inline time picker widget that mimics the iOS clock app's circling time picker.
/// It provides various customization options for a seamless user experience.
class InlineTimePicker extends StatefulWidget
    with
        Invokable,
        HasController<InlineTimePickerController, InlineTimePickerState> {
  static const type = 'InlineTimePicker';

  InlineTimePicker({Key? key}) : super(key: key);

  final InlineTimePickerController _controller = InlineTimePickerController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => InlineTimePickerState();

  @override
  Map<String, Function> getters() {
    return {
      'selectedTime': () => _controller.selectedTimeFormatted(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'reset': () => _controller.reset(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'initialTime': (time) =>
          _controller.initialTime = Utils.getTimeOfDay(time),
      'onTimeChanged': (funcDefinition) => _controller.onTimeChangedAction =
          ensemble.EnsembleAction.from(funcDefinition, initiator: this),
      'mode': (value) => _controller.mode =
          Utils.getEnum<CupertinoTimerPickerMode>(
              value, CupertinoTimerPickerMode.values),
      'minuteInterval': (value) =>
          _controller.minuteInterval = Utils.optionalInt(value),
      'secondInterval': (value) =>
          _controller.secondInterval = Utils.optionalInt(value),
      'onTimeChangedHaptic': (value) =>
          _controller.onTimeChangedHaptic = Utils.optionalString(value),
    };
  }
}

class InlineTimePickerController extends BoxController {
  TimeOfDay? initialTime;
  TimeOfDay? selectedTime;
  int selectedSeconds = 0; // To hold the selected seconds
  ensemble.EnsembleAction? onTimeChangedAction;
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
}

class InlineTimePickerState extends EWidgetState<InlineTimePicker> {
  @override
  void initState() {
    super.initState();
    widget._controller.selectedTime =
        widget._controller.initialTime ?? TimeOfDay.now();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return BoxWrapper(
      widget: CupertinoTimerPicker(
        mode: widget._controller.mode,
        initialTimerDuration: Duration(
          hours: widget._controller.selectedTime?.hour ?? TimeOfDay.now().hour,
          minutes:
              widget._controller.selectedTime?.minute ?? TimeOfDay.now().minute,
          seconds: widget
              ._controller.selectedSeconds, // Initialize with selected seconds
        ),
        onTimerDurationChanged: (Duration newDuration) {
          onTimerDurationChanged(context, newDuration);
        },
        minuteInterval: widget._controller.minuteInterval ?? 1,
        secondInterval: widget._controller.secondInterval ?? 1,
      ),
      boxController: widget._controller,
    );
  }

  void onTimerDurationChanged(BuildContext context, Duration newDuration) {
    setState(() {
      widget._controller.selectedTime = TimeOfDay(
        hour: newDuration.inHours,
        minute: newDuration.inMinutes % 60,
      );
      widget._controller.selectedSeconds = newDuration.inSeconds % 60;
    });

    if (widget._controller.onTimeChangedHaptic != null) {
      ScreenController().executeAction(
        context,
        HapticAction(
            type: widget._controller.onTimeChangedHaptic!, onComplete: null),
      );
    }

    if (widget._controller.onTimeChangedAction != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onTimeChangedAction!,
        event: EnsembleEvent(widget),
      );
    }
  }
}
