import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ensemble/util/extensions.dart';

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
    return {
      'value': () => _controller.value?.toIso8601TimeString(),
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
          _controller.initialValue = Utils.getTimeOfDay(value),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.fromYaml(definition, initiator: this)
    };
  }
}

class TimeController extends FormFieldController {
  TimeOfDay? value;
  String prettyValue(BuildContext context) {
    return value?.format(context) ?? hintText ?? 'Select a time';
  }

  TimeOfDay? initialValue;

  EnsembleAction? onChange;
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
    final picked = await showTimePicker(
      context: context,
      initialTime: widget._controller.initialValue ??
          const TimeOfDay(hour: 12, minute: 0),
      builder: (context, child) {
        return Theme(
            data: ThemeData(
                colorScheme: Theme.of(context)
                    .colorScheme
                    .copyWith(onPrimary: Colors.white)),
            child: child!);
      },
    );
    if (picked != null) {
      if (widget._controller.value == null ||
          widget._controller.value!.compareTo(picked) != 0) {
        setState(() {
          widget._controller.value = picked;
        });
        if (isEnabled() && widget._controller.onChange != null) {
          ScreenController().executeAction(
              context, widget._controller.onChange!,
              event: EnsembleEvent(widget));
        }
      }
    }
  }

  Widget nowBuildWidget() {
    Widget rtn = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.alarm, color: Colors.black54),
        const SizedBox(width: 5),
        Text(widget._controller.prettyValue(context),
            style: TextStyle(fontSize: widget._controller.fontSize?.toDouble()))
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
