
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/widget/widget.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class EnsembleCheckbox extends OnOffWidget {
  static const type = 'Checkbox';
  EnsembleCheckbox({Key? key}) : super(key: key);

  @override
  OnOffType getType() {
    return OnOffType.checkbox;
  }
}

class EnsembleSwitch extends OnOffWidget {
  static const type = 'Switch';
  EnsembleSwitch({Key? key}) : super(key: key);

  @override
  OnOffType getType() {
    return OnOffType.toggle;
  }
}


abstract class OnOffWidget extends StatefulWidget with Invokable, HasController<OnOffController, OnOffState> {
  OnOffWidget({Key? key}) : super(key: key);

  final OnOffController _controller = OnOffController();
  @override
  OnOffController get controller => _controller;

  @override
  State<StatefulWidget> createState() => OnOffState();

  @override
  Map<String, Function> getters() {
    return {
      'value': () => _controller.value
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (newValue) => _controller.value = newValue
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  void onToggle(bool newValue) {
    setProperty('value', newValue);
  }

  OnOffType getType();
}

enum OnOffType {
  checkbox, toggle
}

class OnOffController extends FormFieldController {
  bool value = false;
}

class OnOffState extends WidgetState<OnOffWidget> {
  
  @override
  Widget build(BuildContext context) {
    if (widget.getType() == OnOffType.toggle) {
      return Switch(
          value: widget._controller.value,
          onChanged: (value) => widget.onToggle(value));
    } else {
      return Checkbox(
          value: widget._controller.value,
          onChanged: (bool? value) => widget.onToggle(value ?? false));
    }
  }
}

