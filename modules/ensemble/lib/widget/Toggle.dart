import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// this is an equivalent of Switch/Checkbox but will be used mostly outside of Form
class Toggle extends StatefulWidget
    with Invokable, HasController<ToggleController, ToggleState> {
  static const type = 'Toggle';
  Toggle({super.key});

  final ToggleController _controller = ToggleController();
  @override
  ToggleController get controller => _controller;

  @override
  State<StatefulWidget> createState() => ToggleState();

  @override
  Map<String, Function> getters() {
    return {'value': () => _controller.value};
  }

  @override
  Map<String, Function> methods() {
    return {'toggle': () => _controller.value = !_controller.value};
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (value) =>
          _controller.value = Utils.getBool(value, fallback: false),
      'onChange': (definition) => _controller.onChange =
          EnsembleAction.from(definition, initiator: this),
      'onChangeHaptic': (value) =>
          _controller.onChangeHaptic = Utils.optionalString(value),
      'inactiveWidget': (widget) => _controller.inactiveWidgetDef = widget,
      'activeWidget': (widget) => _controller.activeWidgetDef = widget,
      'transitionDuration': (value) =>
          _controller.transitionDuration = Utils.getDurationMs(value)
    };
  }
}

class ToggleController extends WidgetController {
  bool value = false;
  EnsembleAction? onChange;
  String? onChangeHaptic;

  dynamic inactiveWidgetDef;
  dynamic activeWidgetDef;

  Duration? transitionDuration;
}

class ToggleState extends WidgetState<Toggle> {
  late Widget _inactiveWidget;
  late Widget _activeWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // pre-built both states
    Widget? generated = scopeManager
        ?.buildWidgetFromDefinition(widget._controller.inactiveWidgetDef);
    if (generated == null) {
      throw LanguageError('${Toggle.type} requires an inactiveWidget.');
    }
    _inactiveWidget = generated;

    generated = scopeManager
        ?.buildWidgetFromDefinition(widget._controller.activeWidgetDef);
    if (generated == null) {
      throw LanguageError('${Toggle.type} requires an activeWidget.');
    }
    _activeWidget = generated;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return InkWell(
        onTap: () {
          setState(() {
            widget._controller.value = !widget._controller.value;
          });
          if (widget._controller.onChange != null) {
            if (widget._controller.onChangeHaptic != null) {
              ScreenController().executeAction(
                context,
                HapticAction(
                  type: widget._controller.onChangeHaptic!,
                  onComplete: null,
                ),
              );
            }

            ScreenController()
                .executeAction(context, widget._controller.onChange!);
          }
        },
        child: widget._controller.transitionDuration != null
            ? AnimatedSwitcher(
                duration: widget._controller.transitionDuration!,
                transitionBuilder: (child, animation) {
                  // all the scale/resize animation doesn't really go from one
                  // widget to the other (more like randomly). For now only support
                  // fade transition, which will still look strange if the size
                  // is different
                  return FadeTransition(opacity: animation, child: child);
                },
                child: widget._controller.value
                    ? KeyedSubtree(key: UniqueKey(), child: _activeWidget)
                    : KeyedSubtree(key: UniqueKey(), child: _inactiveWidget))
            : widget._controller.value
                ? _activeWidget
                : _inactiveWidget);
  }
}
