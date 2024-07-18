import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class ToggleContainer extends StatefulWidget
    with
        Invokable,
        HasController<ToggleContainerController, ToggleContainerState> {
  static const type = 'ToggleContainer';
  ToggleContainer({super.key});

  final ToggleContainerController _controller = ToggleContainerController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => ToggleContainerState();

  @override
  Map<String, Function> getters() {
    return {'isFirst': () => _controller.isFirst};
  }

  @override
  Map<String, Function> methods() {
    return {
      'toggle': () => setProperty('isFirst', !_controller.isFirst),
      'showFirst': () => setProperty('isFirst', true),
      'showSecond': () => setProperty('isFirst', false)
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'onToggle': (definition) => _controller.onToggle =
          EnsembleAction.from(definition, initiator: this),
      'isFirst': (value) => _controller.isFirst =
          Utils.getBool(value, fallback: _controller.isFirst),
      'firstWidget': (widget) => _controller.firstWidget = widget,
      'secondWidget': (widget) => _controller.secondWidget = widget,
      'transitionDuration': (value) =>
          _controller.transitionDuration = Utils.getDurationMs(value)
    };
  }
}

class ToggleContainerController extends WidgetController {
  EnsembleAction? onToggle;

  bool isFirst = true;
  dynamic firstWidget;
  dynamic secondWidget;
  Duration? transitionDuration;
}

class ToggleContainerState extends WidgetState<ToggleContainer> {
  final defaultDuration = const Duration(milliseconds: 300);
  late Widget first;
  late Widget second;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // build the widgets
    if (widget._controller.firstWidget == null ||
        widget._controller.secondWidget == null) {
      throw LanguageError(
          "${ToggleContainer.type} requires both firstWidget and secondWidget.");
    }

    Widget? generated =
        scopeManager?.buildWidgetFromDefinition(widget._controller.firstWidget);
    if (generated == null) {
      throw LanguageError(
          '${ToggleContainer.type} requires a valid firstWidget.');
    }
    first = generated;

    generated = scopeManager
        ?.buildWidgetFromDefinition(widget._controller.secondWidget);
    if (generated == null) {
      throw LanguageError(
          '${ToggleContainer.type} requires a valid secondWidget.');
    }
    second = generated;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget._controller.transitionDuration ?? defaultDuration,
      child: AnimatedCrossFade(
          duration: widget._controller.transitionDuration ?? defaultDuration,
          crossFadeState: widget._controller.isFirst
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: first,
          secondChild: second),
    );
  }
}
