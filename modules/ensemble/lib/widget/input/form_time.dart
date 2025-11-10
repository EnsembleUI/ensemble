import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/HasTextPlaceholder.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/widget/helpers/input_wrapper.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

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
      'useIOSStyleTimePicker': (value) => _controller.useIOSStyleTimePicker =
          Utils.getBool(value, fallback: shouldUseIOSStyle()),
      'use24hFormat': (value) =>
          _controller.use24hFormat = Utils.getBool(value, fallback: false),
      'iOSStyles': (value) => _controller.iOSStyles = _parseIOSStyles(value),
      'androidStyles': (value) =>
          _controller.androidStyles = _parseAndroidStyles(value),
      'textStyle': (value) => _controller.textStyle = Utils.getTextStyle(value),
      'showIcon': (value) => _controller.showIcon = Utils.optionalBool(value),
    });
    return setters;
  }

  IOSTimePickerStyle _parseIOSStyles(Map<String, dynamic> styles) {
    return IOSTimePickerStyle(
      backgroundColor: Utils.getColor(styles['backgroundColor']),
      textColor: Utils.getColor(styles['textColor']),
      height: Utils.optionalDouble(styles['height']),
      padding: Utils.getInsets(styles['padding']),
    );
  }

  AndroidTimePickerStyle _parseAndroidStyles(Map<String, dynamic> styles) {
    return AndroidTimePickerStyle(
      initialEntryMode:
          TimePickerEntryMode.values.from(styles['initialEntryMode']) ??
              TimePickerEntryMode.dial,
      cancelText: Utils.optionalString(styles['cancelText']),
      confirmText: Utils.optionalString(styles['confirmText']),
      orientation: Orientation.values.from(styles['orientation']),
      backgroundColor: Utils.getColor(styles['backgroundColor']),
      buttonStyle: _buildButtonStyle(styles['buttonStyle']),
      dialBackgroundColor: Utils.getColor(styles['dialBackgroundColor']),
      dialHandColor: Utils.getColor(styles['dialHandColor']),
      dialTextColor: Utils.getColor(styles['dialTextColor']),
      dialTextStyle: Utils.getTextStyle(styles['dialTextStyle']),
      elevation: Utils.optionalDouble(styles['elevation']),
      entryModeIconColor: Utils.getColor(styles['entryModeIconColor']),
      helpTextStyle: Utils.getTextStyle(styles['helpTextStyle']),
      hourMinuteBackgroundColor:
          Utils.getColor(styles['hourMinuteBackgroundColor']),
      hourMinuteTextStyle: Utils.getTextStyle(styles['hourMinuteTextStyle']),
      padding: Utils.getInsets(styles['padding']),
    );
  }

  static ButtonStyle? _buildButtonStyle(dynamic input) {
    if (input == null) return null;
    return ButtonStyle(
      backgroundColor:
          WidgetStateProperty.all(Utils.getColor(input['backgroundColor'])),
      padding: WidgetStateProperty.all(Utils.getInsets(input['padding'])),
      textStyle:
          WidgetStateProperty.all(Utils.getTextStyle(input['textStyle'])),
      foregroundColor:
          WidgetStateProperty.all(Utils.getColor(input['textStyle']['color'])),
    );
  }
}

class TimeController extends FormFieldController with HasTextPlaceholder {
  TimeOfDay? value;
  TimeOfDay? initialValue;
  EnsembleAction? onChange;
  bool useIOSStyleTimePicker = shouldUseIOSStyle();
  bool use24hFormat = false;
  IOSTimePickerStyle? iOSStyles;
  AndroidTimePickerStyle? androidStyles;
  TextStyle? textStyle;
  bool? showIcon;

  Text prettyValue(BuildContext context, TextStyle formFieldTextStyle) {
    TextStyle timeTextStyle = formFieldTextStyle;

    if (textStyle != null) {
      timeTextStyle = timeTextStyle.copyWith(
        fontSize: textStyle?.fontSize,
        overflow: textStyle?.overflow ?? TextOverflow.ellipsis,
        color: textStyle?.color,
        fontWeight: textStyle?.fontWeight,
      );
    }

    if (value != null) {
      return Text(
        MaterialLocalizations.of(context)
            .formatTimeOfDay(value!, alwaysUse24HourFormat: use24hFormat),
        style: timeTextStyle,
      );
    } else {
      return Text(
        placeholder ?? MaterialLocalizations.of(context).timePickerDialHelpText,
        style: placeholderStyle,
      );
    }
  }
}

bool shouldUseIOSStyle() {
  if (kIsWeb) {
    // For web, use iOS style for browser which is on Apple platforms.
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  } else {
    // For native platforms, use iOS style only on iOS
    return defaultTargetPlatform == TargetPlatform.iOS;
  }
}

class IOSTimePickerStyle {
  Color? backgroundColor;
  Color? textColor;
  double? height;
  EdgeInsets? padding;

  IOSTimePickerStyle({
    this.backgroundColor,
    this.textColor,
    this.height,
    this.padding,
  });
}

class AndroidTimePickerStyle {
  final TimePickerEntryMode initialEntryMode;
  final String? cancelText;
  final String? confirmText;
  final Orientation? orientation;
  final Color? backgroundColor;
  final ButtonStyle? buttonStyle;
  final Color? dialBackgroundColor;
  final Color? dialHandColor;
  final Color? dialTextColor;
  final TextStyle? dialTextStyle;
  final double? elevation;
  final Color? entryModeIconColor;
  final TextStyle? helpTextStyle;
  final Color? hourMinuteBackgroundColor;
  final TextStyle? hourMinuteTextStyle;
  final EdgeInsetsGeometry? padding;

  AndroidTimePickerStyle({
    this.initialEntryMode = TimePickerEntryMode.dial,
    this.cancelText,
    this.confirmText,
    this.orientation,
    this.backgroundColor,
    this.buttonStyle,
    this.dialBackgroundColor,
    this.dialHandColor,
    this.dialTextColor,
    this.dialTextStyle,
    this.elevation,
    this.entryModeIconColor,
    this.helpTextStyle,
    this.hourMinuteBackgroundColor,
    this.hourMinuteTextStyle,
    this.padding,
  });
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
          if (widget._controller.required && widget._controller.value == null) {
            return Utils.translateWithFallback('ensemble.input.required',
                widget._controller.requiredMessage ?? 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<DateTime> field) {
          final hasBorderProperties = widget._controller.borderColor != null ||
              widget._controller.borderWidth != null ||
              widget._controller.borderRadius != null ||
              widget._controller.variant != null ||
              widget._controller.enabledBorderColor != null ||
              widget._controller.disabledBorderColor != null ||
              widget._controller.errorBorderColor != null ||
              widget._controller.focusedBorderColor != null ||
              widget._controller.focusedErrorBorderColor != null;

          // If no border properties are set, use InputBorder.none (default behavior)
          // Otherwise, use the inputDecoration which will respect the border properties
          final decoration = hasBorderProperties
              ? inputDecoration.copyWith(
                  errorText: field.errorText,
                  errorStyle: widget._controller.errorStyle ??
                      Theme.of(context).inputDecorationTheme.errorStyle,
                )
              : inputDecoration.copyWith(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  errorText: field.errorText,
                  errorStyle: widget._controller.errorStyle ??
                      Theme.of(context).inputDecorationTheme.errorStyle,
                );

          return InputDecorator(
            decoration: decoration,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  child: nowBuildWidget(),
                  onTap: isEnabled() ? () => _selectTime(context) : null,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _selectTime(BuildContext context) async {
    if (widget._controller.useIOSStyleTimePicker) {
      _showCupertinoTimePicker(context);
    } else {
      _showMaterialTimePicker(context);
    }
  }

  void _showCupertinoTimePicker(BuildContext context) {
    final iosStyles = widget._controller.iOSStyles;
    final userSetBackgroundColor = iosStyles?.backgroundColor;
    final backgroundColor = userSetBackgroundColor ??
        CupertinoTheme.of(context).scaffoldBackgroundColor;
    final textColor = iosStyles?.textColor;

    Color? pickerTextColor;
    if (textColor != null) {
      // User explicitly set text color, use it
      pickerTextColor = textColor;
    } else if (userSetBackgroundColor != null) {
      // User set background but not text color, auto-detect for contrast
      final brightness =
          ThemeData.estimateBrightnessForColor(userSetBackgroundColor);
      pickerTextColor =
          brightness == Brightness.dark ? Colors.white : Colors.black;
    }

    showCupertinoModalPopup<void>(
      context: context,
      builder: (BuildContext context) => Container(
        height: iosStyles?.height ?? 216,
        padding: iosStyles?.padding ?? const EdgeInsets.only(top: 6.0),
        color: backgroundColor,
        child: SafeArea(
          top: false,
          child: pickerTextColor != null
              ? DefaultTextStyle(
                  style: TextStyle(color: pickerTextColor),
                  child: CupertinoTheme(
                    data: CupertinoTheme.of(context).copyWith(
                      primaryColor: pickerTextColor,
                      brightness: ThemeData.estimateBrightnessForColor(
                                  backgroundColor) ==
                              Brightness.dark
                          ? Brightness.dark
                          : Brightness.light,
                    ),
                    child: CupertinoDatePicker(
                      initialDateTime: DateTime.now().copyWith(
                        hour: widget._controller.value?.hour ??
                            TimeOfDay.now().hour,
                        minute: widget._controller.value?.minute ??
                            TimeOfDay.now().minute,
                      ),
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: widget._controller.use24hFormat,
                      onDateTimeChanged: (DateTime newDateTime) {
                        _updateTime(TimeOfDay.fromDateTime(newDateTime));
                      },
                    ),
                  ),
                )
              : CupertinoDatePicker(
                  initialDateTime: DateTime.now().copyWith(
                    hour:
                        widget._controller.value?.hour ?? TimeOfDay.now().hour,
                    minute: widget._controller.value?.minute ??
                        TimeOfDay.now().minute,
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

  void _showMaterialTimePicker(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: widget._controller.value ?? TimeOfDay.now(),
      initialEntryMode: widget._controller.androidStyles?.initialEntryMode ??
          TimePickerEntryMode.dial,
      cancelText: widget._controller.androidStyles?.cancelText,
      confirmText: widget._controller.androidStyles?.confirmText,
      orientation: widget._controller.androidStyles?.orientation,
      builder: (context, child) {
        return Theme(
          data: _getTimePickerTheme(context),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
                alwaysUse24HourFormat: widget._controller.use24hFormat),
            child: child!,
          ),
        );
      },
    );
    _updateTime(picked);
  }

  ThemeData _getTimePickerTheme(BuildContext context) {
    final androidStyles = widget._controller.androidStyles;
    return Theme.of(context).copyWith(
      timePickerTheme: TimePickerThemeData(
        backgroundColor: androidStyles?.backgroundColor,
        hourMinuteColor: androidStyles?.hourMinuteBackgroundColor,
        dayPeriodColor: androidStyles?.hourMinuteBackgroundColor,
        dialBackgroundColor: androidStyles?.dialBackgroundColor,
        dialHandColor: androidStyles?.dialHandColor,
        dialTextColor: androidStyles?.dialTextColor,
        entryModeIconColor: androidStyles?.entryModeIconColor,
        hourMinuteTextStyle: androidStyles?.hourMinuteTextStyle,
        hourMinuteTextColor: androidStyles?.hourMinuteTextStyle?.color,
        dayPeriodTextColor: androidStyles?.hourMinuteTextStyle?.color,
        helpTextStyle: androidStyles?.helpTextStyle,
      ),
      textButtonTheme: TextButtonThemeData(
        style: androidStyles?.buttonStyle,
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
    List<Widget> children = [];

    // Only show icon if showIcon is not explicitly set to false
    if (widget._controller.showIcon != false) {
      children.add(const Icon(Icons.alarm, color: Colors.black54));
      children.add(const SizedBox(width: 5));
    }

    children.add(widget._controller.prettyValue(context, formFieldTextStyle));

    Widget rtn = Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
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
