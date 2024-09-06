import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

class Time extends StatefulWidget
    with Invokable, HasController<TimeController, TimeState> {
  static const type = 'Time';

  Time({Key? key}) : super(key: key);

  final TimeController _controller = TimeController();

  @override
  TimeController get controller => _controller;

  @override
  State<StatefulWidget> createState() => TimeState();

  @override
  Map<String, Function> getters() {
    var getters = _controller.textPlaceholderGetters;
    getters.addAll({
      'value': () => _controller.value?.toIso8601TimeString(),
    });
    return getters;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    var setters = _controller.textPlaceholderSetters;
    setters.addAll({
      'initialValue': (value) {
        _controller.initialValue = Utils.getTimeOfDay(value);
        _controller.value =
            _controller.initialValue; // Set the current value to initialValue
      },
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'useIOSStyleTimePicker': (value) =>
          _controller.useIOSStyleTimePicker = Utils.getBool(value, fallback: Platform.isIOS),
      'use24hFormat': (value) => _controller.use24hFormat = Utils.getBool(value, fallback: false),
      'pickerHeight': (value) => _controller.pickerHeight =  Utils.optionalDouble(value),
      'pickerPadding': (value) => _controller.pickerPadding = Utils.getInsets(value) ,
      'pickerBackgroundColor': (value) => _controller.pickerBackgroundColor = Utils.getColor(value),
    
    });                         
    return setters;
  }
}

class TimeController extends FormFieldController with HasTextPlaceholder {
  TimeOfDay? value;
  TimeOfDay? initialValue;
  EnsembleAction? onChange;
  bool useIOSStyleTimePicker = Platform.isIOS;
  bool use24hFormat = false;
  double? pickerHeight;
  EdgeInsets? pickerPadding;
  Color? pickerBackgroundColor;

  Text prettyValue(BuildContext context) {
    if (value != null) {
      return Text(
        MaterialLocalizations.of(context).formatTimeOfDay(value!, alwaysUse24HourFormat: use24hFormat),
        style: TextStyle(fontSize: fontSize?.toDouble()),
      );
    } else {
      return Text(
        placeholder ?? MaterialLocalizations.of(context).timePickerDialHelpText,
        style: placeholderStyle,
      );
    }
  }
}

class TimeState extends FormFieldWidgetState<Time> {
  @override
  Widget buildWidget(BuildContext context) {
    return InputWrapper(
        type: Time.type,
        controller: widget.controller,
        widget: FormField<DateTime>(
            key: validatorKey,
            validator: (value) {
              if (widget._controller.required &&
                  widget._controller.value == null) {
                return Utils.translateWithFallback(
                    'ensemble.input.required', 'This field is required');
              }
              return null;
            },
            builder: (FormFieldState<DateTime> field) {
              return InputDecorator(
                  decoration: inputDecoration.copyWith(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      errorText: field.errorText),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    InkWell(
                        child: nowBuildWidget(),
                        onTap: isEnabled() ? () => _selectTime(context) : null)
                  ]));
            }));
  }

  void _selectTime(BuildContext context) async {
    if (widget._controller.useIOSStyleTimePicker) {
      _showCupertinoTimePicker(context);
    } else {
      final picked = await showTimePicker(
        context: context,
        initialTime: widget._controller.value ?? TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData(
                colorScheme: Theme.of(context)
                    .colorScheme
                    .copyWith(onPrimary: Colors.white)),
            child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    alwaysUse24HourFormat: widget._controller.use24hFormat),
                child: child!),
          );
        },
      );
      _updateTime(picked);
    }
  }

  void _showCupertinoTimePicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height:  widget._controller.pickerHeight ?? 216,
        padding: widget._controller.pickerPadding ?? const EdgeInsets.only(top: 6.0),
        color: widget._controller.pickerBackgroundColor ?? CupertinoTheme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          top: false,
          child: CupertinoDatePicker(
              initialDateTime: DateTime.now().copyWith(
                hour: widget._controller.value?.hour ?? TimeOfDay.now().hour,
                minute: widget._controller.value?.minute ?? TimeOfDay.now().minute,
              ),
              mode: CupertinoDatePickerMode.time,
              use24hFormat: widget._controller.use24hFormat,
              onDateTimeChanged: (DateTime newDateTime) {
                _updateTime(TimeOfDay.fromDateTime(newDateTime));
              },
            ),
        ),
      ),
    );
  }

  void _updateTime(TimeOfDay? picked) {
    if (picked != null &&
        (widget._controller.value == null ||
            widget._controller.value!.compareTo(picked) != 0)) {
      setState(() {
        widget._controller.value = picked;
      });
      if (isEnabled() && widget._controller.onChange != null) {
        ScreenController().executeAction(context, widget._controller.onChange!,
            event: EnsembleEvent(widget));
      }
    }
  }

  Widget nowBuildWidget() {
    Widget rtn = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.alarm, color: Colors.black54),
        const SizedBox(width: 5),
        widget._controller.prettyValue(context),
      ],
    );
    if (!isEnabled()) {
      rtn = Opacity(
        opacity: .5,
        child: rtn,
      );
    }
    return rtn;
  }
}
