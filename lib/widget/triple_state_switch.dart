import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/input/form_helper.dart';
import 'package:ensemble/framework/action.dart' as framework;
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleTripleStateSwitch extends StatefulWidget
    with
        Invokable,
        HasController<TripleStateSwitchController,
            EnsembleTripleStateSwitchState> {
  static const type = 'TripleStateSwitch';
  EnsembleTripleStateSwitch({Key? key}) : super(key: key);

  final TripleStateSwitchController _controller = TripleStateSwitchController();
  @override
  TripleStateSwitchController get controller => _controller;

  @override
  State<StatefulWidget> createState() => EnsembleTripleStateSwitchState();

  @override
  Map<String, Function> getters() {
    return {'value': () => _controller.value.name};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) => _controller.value =
          SwitchState.values.from(Utils.getString(value, fallback: 'start')) ??
              SwitchState.start,
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

  void onToggle(SwitchState newValue) {
    setProperty('value', newValue.name);
  }
}

class TripleStateSwitchController extends FormFieldController {
  SwitchState value = SwitchState.start;
  String? leadingText;
  String? trailingText;
  Color? activeColor;
  Color? activeThumbColor;
  Color? inactiveColor;
  Color? inactiveThumbColor;
  Color? intermediateColor;

  framework.EnsembleAction? onChange;
}

class EnsembleTripleStateSwitchState
    extends FormFieldWidgetState<EnsembleTripleStateSwitch> {
  void onToggle(SwitchState newValue) {
    widget.onToggle(newValue);
    widget._controller.value = newValue;
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

    children.add(switchWidget);

    if (widget._controller.trailingText != null) {
      children.add(Expanded(
          child: Text(
        widget._controller.trailingText!,
        style: formFieldTextStyle,
      )));
    }

    // wraps around FormField to get all the form effects
    return InputWrapper(
      type: EnsembleTripleStateSwitch.type,
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

  Widget get switchWidget {
    return TripleStateSwitch(
      dotColor: widget._controller.activeThumbColor,
      disableDotColor: widget._controller.inactiveThumbColor,
      startBackgroundColor: widget._controller.activeColor,
      middleBackgroundColor: widget._controller.intermediateColor,
      endBackgroundColor: widget._controller.inactiveColor,
      disable: widget._controller.enabled == false,
      state: widget._controller.value,
      onChanged: isEnabled() ? (value) => onToggle(value) : (_) {},
    );
  }
}

enum SwitchState {
  start,
  middle,
  end;
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
            ? state == SwitchState.start
                ? startBackgroundColor ?? SwitchColors.backgroundColor
                : state == SwitchState.middle
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
                            onChanged(SwitchState.start);
                          }
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: !disable!
                        ? () {
                            onChanged(SwitchState.middle);
                          }
                        : null,
                    child: const SizedBox.expand(),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: !disable!
                        ? () {
                            onChanged(SwitchState.end);
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
            alignment: state == SwitchState.start
                ? AlignmentDirectional.centerStart
                : state == SwitchState.middle
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

class SwitchColors {
  SwitchColors._();

  static const Color backgroundColor = Color(0xFFd1d1d1);
  static const Color dotColor = Color(0xFFFFFFFF);
  static const Color disableBackgroundColor = Color(0xFFbfbfbf);
  static const Color disableDotColor = Color(0xFFe3e3e3);
}
