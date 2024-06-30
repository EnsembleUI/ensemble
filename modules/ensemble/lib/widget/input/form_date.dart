import 'package:ensemble/ensemble_theme.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/widget_registry.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:ensemble/util/extensions.dart';

class Date extends StatefulWidget
    with Invokable, HasController<DateController, DateState> {
  static const type = 'Date';

  Date({Key? key}) : super(key: key);

  final DateController _controller = DateController();

  @override
  DateController get controller => _controller;

  @override
  State<StatefulWidget> createState() => DateState();

  @override
  Map<String, Function> getters() {
    var getters = _controller.textPlaceholderGetters;
    getters.addAll({
      'value': () => _controller.value?.toIso8601DateString(),
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
      'initialValue': (value) => _controller.value ??= Utils.getDate(value),
      'firstDate': (value) => _controller.firstDate = Utils.getDate(value),
      'lastDate': (value) => _controller.lastDate = Utils.getDate(value),
      'showCalendarIcon': (shouldShow) =>
          _controller.showCalendarIcon = Utils.optionalBool(shouldShow),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this)
    });
    return setters;
  }
}

class DateController extends FormFieldController with HasTextPlaceholder {
  DateTime? value;

  // first and last available dates to be selected
  DateTime? firstDate;
  DateTime? lastDate;

  bool? showCalendarIcon;
  EnsembleAction? onChange;
}

class DateState extends FormFieldWidgetState<Date> {
  String? validationText;

  /// the selected date nicely formatted
  String get selectedValue => widget._controller.value != null
      ? DateFormat.yMMMd(Localizations.localeOf(context).toString())
          .format(widget._controller.value!)
      : '';

  @override
  Widget buildWidget(BuildContext context) {
    return InputWrapper(
        type: Date.type,
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
              Widget rtn = InkWell(
                  onTap: isEnabled() ? () => _selectDate(context) : null,
                  child: InputDecorator(
                      isEmpty: widget._controller.value == null,
                      decoration: inputDecoration.copyWith(
                          errorText: field.errorText,
                          hintText: widget._controller.placeholder ??
                              widget._controller.hintText ??
                              Utils.translateWithFallback(
                                  'ensemble.input.date.placeholder',
                                  'Select a date'),
                          suffixIcon: widget._controller.showCalendarIcon !=
                                  false
                              ? Icon(Icons.calendar_month_rounded,
                                  color:
                                      formFieldTextStyle.color?.withOpacity(.5),
                                  size: ThemeManager()
                                      .getInputIconSize(context)
                                      .toDouble())
                              : null),
                      child: ClearableInput(
                          text: selectedValue,
                          textStyle: formFieldTextStyle,
                          enabled: widget._controller.enabled ?? true,
                          onCleared: () {
                            setState(() {
                              widget._controller.value = null;
                            });
                          })));

              if (!isEnabled()) {
                rtn = Opacity(
                  opacity: .5,
                  child: rtn,
                );
              }
              return rtn;
            }));
  }

  void _selectDate(BuildContext context) async {
    // massage the dates to ensure initial date falls between firstDate and lastDate
    DateTime firstDate = widget._controller.firstDate ?? DateTime(1900);
    DateTime lastDate = widget._controller.lastDate ?? DateTime(2050);
    if (firstDate.isAfter(lastDate)) {
      firstDate = lastDate;
    }
    DateTime initialDate = widget._controller.value ?? DateTime.now().toDate();
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    } else if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: ThemeData(
            textTheme: Theme.of(context).textTheme,
            colorScheme:
                Theme.of(context).colorScheme.copyWith(onPrimary: Colors.white),
          ),
          child: child!,
        );
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
}
