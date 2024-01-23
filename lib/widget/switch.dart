import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleTripleStateSwitch extends SwitchBase {
  static const type = 'TripleStateSwitch';
  EnsembleTripleStateSwitch({super.key});
}

class EnsembleSwitch extends SwitchBase {
  static const type = 'Switch';
  EnsembleSwitch({super.key});
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
      'value': (value) => setSwitchValue(value),
      'leadingText': (text) =>
          _controller.leadingText = Utils.optionalString(text),
      'trailingText': (text) =>
          _controller.trailingText = Utils.optionalString(text),
      'activeColor': (color) => _controller.activeColor = Utils.getColor(color),
      'inactiveColor': (color) =>
          _controller.inactiveColor = Utils.getColor(color),
      'intermediateColor': (color) =>
          _controller.intermediateColor = Utils.getColor(color),
      'activeThumbColor': (color) =>
          _controller.activeThumbColor = Utils.getColor(color),
      'inactiveThumbColor': (color) =>
          _controller.inactiveThumbColor = Utils.getColor(color),
      'onChange': (definition) => _controller.onChange =
          framework.EnsembleAction.fromYaml(definition, initiator: this)
    };
  }

  void setSwitchValue(dynamic value) {
    if (value is bool) {
      _controller.value = Utils.getBool(value, fallback: false);
    } else if (value is String) {
      _controller.value = SwitchState.values.from(value) ?? _controller.value;
    }
  }

  void onToggle(dynamic newValue) {
    setProperty('value', newValue);
  }
}

class SwitchBaseState extends FormFieldWidgetState<SwitchBase> {
  void onToggle(dynamic newValue) {
    if (newValue is bool) {
      widget.onToggle(newValue);
      widget._controller.value = newValue;
    } else if (newValue is String) {
      final SwitchState switchState =
          SwitchState.values.from(newValue) ?? widget._controller.value;
      widget.onToggle(switchState);
      widget._controller.value = switchState;
    }
    if (widget._controller.onChange != null) {
      ScreenController().executeAction(context, widget._controller.onChange!,
          event: EnsembleEvent(widget));
    }
  }

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

    children.add(widget is EnsembleSwitch ? switchWidget : tripleStateSwitch);

    if (widget._controller.trailingText != null) {
      children.add(Expanded(
          child: Text(
        widget._controller.trailingText!,
        style: formFieldTextStyle,
      )));
    }

    // wraps around FormField to get all the form effects
    return InputWrapper(
      // type: EnsembleTripleStateSwitch.type,
      type: '',
      controller: widget._controller,
      widget: FormField<bool>(
        key: validatorKey,
        validator: (value) {
          if (widget._controller.required) {
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

  Widget get tripleStateSwitch {
    return TripleStateSwitch(
      dotColor: widget._controller.activeThumbColor,
      disableDotColor: widget._controller.inactiveThumbColor,
      startBackgroundColor: widget._controller.activeColor,
      middleBackgroundColor: widget._controller.intermediateColor,
      endBackgroundColor: widget._controller.inactiveColor,
      disable: widget._controller.enabled == false,
      state: widget._controller.value,
      onChanged: isEnabled() ? (value) => onToggle(value.name) : (_) {},
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
        value: widget._controller.value,
        onChanged: isEnabled() ? (value) => onToggle(value) : null);
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
  Color? intermediateColor;

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
                    ? middleBackgroundColor ?? SwitchColors.backgroundColor
                    : endBackgroundColor ?? SwitchColors.backgroundColor
            : SwitchColors.disableBackgroundColor,
        borderRadius: borderRadius ??
            BorderRadius.circular(
              200,
            ),
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
