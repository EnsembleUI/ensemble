import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/model/shared_models.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class EnsembleStack extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<StackController, StackState> {
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
  void initChildren({List<WidgetModel>? children, ItemTemplate? itemTemplate}) {
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
      'alignChildren': (value) =>
          _controller.alignChildren = Utils.getAlignment(value),
    };
  }
}

class StackController extends WidgetController {
  List<WidgetModel>? children;
  Alignment? alignChildren;
}

class StackState extends WidgetState<EnsembleStack>
    with HasChildren<EnsembleStack> {
  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.children == null ||
        widget._controller.children!.isEmpty) {
      return const SizedBox.shrink();
    }
    Widget stackWidget = Stack(
      alignment: widget._controller.alignChildren ?? Alignment.topLeft,
      children: buildChildren(widget._controller.children!),
    );
    if (StudioDebugger().debugMode) {
      stackWidget = RequireStackWidget(child: stackWidget);
    }
    return stackWidget;
  }
}
