import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EnsembleSpacer extends StatefulWidget
    with Invokable, HasController<SpacerController, SpacerState> {
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
      'size': (value) => _controller.size = Utils.optionalInt(value),
      'flex': (value) => _controller.flex = Utils.optionalInt(value, min: 1),
    };
  }

  /// NOTE: Spacer should not take expanded into account
}

class SpacerController extends Controller with HasStyles {
  int? size;
  int? flex;
}

class SpacerState extends WidgetState<EnsembleSpacer> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.size != null) {
      return SizedBox(
          width: widget._controller.size!.toDouble(),
          height: widget._controller.size!.toDouble());
    }
    return Spacer(flex: widget._controller.flex ?? 1);
  }
}
