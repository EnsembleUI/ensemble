
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EnsembleStack extends StatefulWidget with UpdatableContainer, Invokable, HasController<StackController, StackState> {
  static const type = 'Stack';
  EnsembleStack({Key? key}) : super(key: key);

  late final List<Widget>? children;
  late final ItemTemplate? itemTemplate;

  final StackController _controller = StackController();


  @override
  StackController get controller => _controller;

  @override
  State<StatefulWidget> createState() => StackState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'alignment': (value) => _controller.alignment = Utils.getAlignment(value),
    };
  }

}


class StackController extends WidgetController {
  List<Widget>? children;

  Alignment? alignment;

}

class StackState extends WidgetState<EnsembleStack> {
  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible ||
        widget._controller.children == null ||
        widget._controller.children!.isEmpty ) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: widget._controller.children!,
      alignment: widget._controller.alignment ?? AlignmentDirectional.topStart,
    );
  }

}