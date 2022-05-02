
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

class Stack extends StatefulWidget with UpdatableContainer, Invokable, HasController<StackController, StackState> {
  static const type = 'Stack';
  Stack({Key? key}) : super(key: key);

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
    this.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'width': (value) => _controller.width = Utils.optionalInt(value),
      'height': (value) => _controller.height = Utils.optionalInt(value),
    };
  }

}


class StackController extends WidgetController {
  int? width;
  int? height;
}

class StackState extends WidgetState<Stack> {
  @override
  Widget build(BuildContext context) {
    // TODO: implement build
    throw UnimplementedError();
  }

}