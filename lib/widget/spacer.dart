import 'package:ensemble/framework/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EnsembleSpacer extends StatefulWidget with Invokable, HasController<SpacerController, SpacerState> {
  static const type = 'Spacer';
  EnsembleSpacer({Key? key}) : super(key: key);

  final SpacerController _controller = SpacerController();
  @override
  SpacerController get controller => _controller;

  @override
  State<StatefulWidget> createState() => SpacerState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'size': (value) => Utils.optionalInt(value)
    };
  }

}

class SpacerController extends WidgetController {
  int? size;
}

class SpacerState extends WidgetState<EnsembleSpacer> {
  @override
  Widget build(BuildContext context) {
    if (widget._controller.size != null) {
      return SizedBox(
          width: widget._controller.size!.toDouble(),
          height: widget._controller.size!.toDouble());
    }
    return const Spacer();
  }


}