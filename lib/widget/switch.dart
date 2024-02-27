import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/helpers/form_helper.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

/// A toggle switch (true/false) states
class EnsembleSwitch extends SwitchBase {
  static const type = 'Switch';
  EnsembleSwitch({super.key});

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'value': (value) =>
          _controller.value = Utils.getBool(value, fallback: false),
    });

  void onToggle(bool newValue) {
    setProperty('value', newValue);
  }
}

/// A triple state switch (off/mixed/on) states
class EnsembleTripleSwitch extends SwitchBase {
  static const type = 'TripleSwitch';
  EnsembleTripleSwitch({super.key});

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'value': (value) => _controller.value =
          SwitchState.values.from(value)?.name ?? SwitchState.off.name,
      'height': (value) => _controller.height = Utils.optionalDouble(value),
      'width': (value) => _controller.width = Utils.optionalDouble(value),
    });

  void onToggle(SwitchState newValue) {
    setProperty('value', newValue.name);
  }
}

abstract class SwitchBase extends StatefulWidget
    with Invokable, HasController<SwitchBaseController, SwitchBaseState> {
  SwitchBase({Key? key}) : super(key: key);

  final SwitchBaseController _controller = SwitchBaseController();
  @override
  SwitchBaseController get controller => _controller;

  @override
  State<StatefulWidget> createState() => SwitchBaseState();

  @override
  Map<String, Function> getters() {
    return {'value': () => _controller.value};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.value = value,
      'leadingText': (text) =>
          _controller.leadingText = Utils.optionalString(text),
      'trailingText': (text) =>
          _controller.trailingText = Utils.optionalString(text),
      'activeColor': (color) => _controller.activeColor = Utils.getColor(color),
      'inactiveColor': (color) =>
          _controller.inactiveColor = Utils.getColor(color),
      'mixedColor': (color) => _controller.mixedColor = Utils.getColor(color),
      'activeThumbColor': (color) =>
          _controller.activeThumbColor = Utils.getColor(color),
      'inactiveThumbColor': (color) =>
          _controller.inactiveThumbColor = Utils.getColor(color),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this)
    };
  }
}

class SwitchBaseState extends FormFieldWidgetState<SwitchBase> {
  @override
  Widget buildWidget(BuildContext context) {
    // add leading/trailing text + the actual widget
    List<Widget> children = [];
    if (widget._controller.leadingText != null) {
      children.add(Flexible(
          child: Text(
        widget._controller.leadingText!,
        style: formFieldTextStyle,
      )));
    }

    children.add(widget is EnsembleSwitch ? switchWidget : tripleSwitch);

    if (widget._controller.trailingText != null) {
      children.add(Expanded(
          child: Text(
        widget._controller.trailingText!,
        style: formFieldTextStyle,
      )));
    }

    // wraps around FormField to get all the form effects
    return InputWrapper(
      type: (widget is EnsembleSwitch)
          ? EnsembleSwitch.type
          : EnsembleTripleSwitch.type,
      controller: widget._controller,
      widget: FormField<bool>(
        key: validatorKey,
        validator: (value) {
          final switchRequiredStatus = widget is EnsembleSwitch &&
              widget._controller.required &&
              !widget._controller.value;

          final tripleStateRequiredStatus = widget is EnsembleTripleSwitch &&
              widget._controller.required &&
              widget._controller.value == SwitchState.off.name;

          if (switchRequiredStatus || tripleStateRequiredStatus) {
            return Utils.translateWithFallback(
                'ensemble.input.required', 'This field is required');
          }
          return null;
        },
        builder: (FormFieldState<bool> field) {
          return InputDecorator(
            decoration: inputDecoration.copyWith(
                contentPadding: EdgeInsets.zero,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorText: field.errorText),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.start, children: children),
          );
        },
      ),
    );
  }

  Widget get tripleSwitch {
    final SwitchState switchState =
        SwitchState.values.from(widget._controller.value) ?? SwitchState.off;
    return TripleStateSwitch(
      dotColor: widget._controller.activeThumbColor,
      disableDotColor: widget._controller.inactiveThumbColor,
      startBackgroundColor: widget._controller.activeColor,
      middleBackgroundColor: widget._controller.mixedColor,
      endBackgroundColor: widget._controller.inactiveColor,
      width: widget._controller.width,
      height: widget._controller.height,
      disable: widget._controller.enabled == false,
      state: switchState,
      onChanged: isEnabled()
          ? (value) {
              (widget as EnsembleTripleSwitch?)?.onToggle(value);
              onChange();
            }
          : (_) {},
    );
  }

  Widget get switchWidget {
    final MaterialStateProperty<Color?> trackColor =
        MaterialStateProperty.resolveWith<Color?>(
      (Set<MaterialState> states) {
        // Track color when the switch is selected.
        if (states.contains(MaterialState.selected)) {
          return widget._controller.activeColor;
        }

        // Track color for other states.
        return widget._controller.inactiveColor;
      },
    );

    final MaterialStateProperty<Color?> thumbColor =
        MaterialStateProperty.resolveWith<Color?>(
      (Set<MaterialState> states) {
        // Thumb color when the switch is selected.
        if (states.contains(MaterialState.selected)) {
          return widget._controller.activeThumbColor;
        }

        // Thumb color for other states.
        return widget._controller.inactiveThumbColor;
      },
    );
    return Switch(
        trackColor: trackColor,
        thumbColor: thumbColor,
        value: widget._controller.value == true,
        onChanged: isEnabled()
            ? (value) {
                (widget as EnsembleSwitch?)?.onToggle(value);
                onChange();
              }
            : null);
  }

  void onChange() {
    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget));
    }
  }
}

class SwitchBaseController extends FormFieldController {
  dynamic value;
  String? leadingText;
  String? trailingText;
  Color? activeColor;
  Color? activeThumbColor;
  Color? inactiveColor;
  Color? inactiveThumbColor;
  Color? mixedColor;
  double? width = 80;
  double? height = 30;

  framework.EnsembleAction? onChange;
}

class SwitchColors {
  SwitchColors._();

  static const Color backgroundColor = Color(0xFFd1d1d1);
  static const Color dotColor = Color(0xFFFFFFFF);
  static const Color disableBackgroundColor = Color(0xFFbfbfbf);
  static const Color disableDotColor = Color(0xFFe3e3e3);
}

enum SwitchState {
  off,
  mixed,
  on,
}

class TripleStateSwitch extends StatelessWidget {
  const TripleStateSwitch({
    Key? key,
    required this.onChanged,
    required this.state,
    this.startBackgroundColor,
    this.middleBackgroundColor,
    this.endBackgroundColor,
    this.dotColor,
    this.disableBackgroundColor,
    this.disableDotColor,
    this.width = 70,
    this.height = 30,
    this.child,
    this.borderRadius,
    this.disable = false,
  }) : super(key: key);

  final Function(SwitchState) onChanged;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? startBackgroundColor;
  final Color? middleBackgroundColor;
  final Color? endBackgroundColor;
  final Color? dotColor;
  final Color? disableBackgroundColor;
  final Color? disableDotColor;
  final Widget? child;
  final SwitchState state;
  final bool? disable;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: !disable!
            ? state == SwitchState.off
                ? startBackgroundColor ?? SwitchColors.backgroundColor
                : state == SwitchState.mixed
                    ? middleBackgroundColor ?? Colors.grey
                    : endBackgroundColor ?? Theme.of(context).primaryColor
            : SwitchColors.disableBackgroundColor,
        borderRadius: borderRadius ??
            BorderRadius.circular(
              200,
            ),
      ),
      margin: const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 1,
        vertical: 2,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: !disable!
                        ? () {
                            onChanged(SwitchState.off);
                          }
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: !disable!
                        ? () {
                            onChanged(SwitchState.mixed);
                          }
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: !disable!
                        ? () {
                            onChanged(SwitchState.on);
                          }
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
              ],
            ),
          ),
          AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            alignment: state == SwitchState.off
                ? AlignmentDirectional.centerStart
                : state == SwitchState.mixed
                    ? AlignmentDirectional.center
                    : AlignmentDirectional.centerEnd,
            child: child ??
                Container(
                  height: height,
                  width: height,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: !disable!
                        ? dotColor ?? SwitchColors.dotColor
                        : SwitchColors.disableDotColor,
                    boxShadow: !disable!
                        ? [
                            const BoxShadow(
                              color: Colors.black,
                              blurRadius: 10,
                              spreadRadius: -5,
                            ),
                          ]
                        : null,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}
