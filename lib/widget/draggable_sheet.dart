import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

class DraggableSheet extends StatefulWidget
    with
        Invokable,
        HasController<DraggableSheetController, DraggableSheetState> {
  static const type = 'DraggableSheet';

  final DraggableSheetController _controller = DraggableSheetController();

  DraggableSheet({super.key});

  @override
  DraggableSheetController get controller => _controller;

  @override
  State<StatefulWidget> createState() => DraggableSheetState();

  @override
  Map<String, Function> getters() {
    return {
      'scrollController': () => _controller.scrollController,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'initialSize': (value) =>
          _controller.initialSize = Utils.optionalDouble(value),
      'minSize': (value) => _controller.minSize = Utils.optionalDouble(value),
      'maxSize': (value) => _controller.maxSize = Utils.optionalDouble(value),
      'span': (value) => _controller.span = Utils.optionalBool(value),
      'expand': (value) => _controller.expand = Utils.optionalBool(value),
      'spanSizes': (value) =>
          _controller.spanSizes = Utils.getList<double>(value),
      'decoration': (value) =>
          _controller.boxDecoration = Utils.getBoxDecoration(value),
      'widget': (value) => _controller.child = value,
    };
  }
}

class DraggableSheetController extends WidgetController {
  double? initialSize;
  double? minSize;
  double? maxSize;
  bool? span;
  bool? expand;
  List<double>? spanSizes;
  BoxDecoration? boxDecoration;
  dynamic child;
  ScrollController? scrollController;
}

class DraggableSheetState extends WidgetState<DraggableSheet> {
  @override
  Widget buildWidget(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: widget._controller.initialSize ?? 0.5,
      minChildSize: widget._controller.minSize ?? 0.25,
      maxChildSize: widget._controller.maxSize ?? 1.0,
      expand: widget._controller.expand ?? true,
      snap: widget._controller.span ?? false,
      snapSizes: widget._controller.spanSizes,
      builder: (context, scrollController) {
        widget._controller.scrollController = scrollController;
        Widget? child;
        if (widget._controller.child != null) {
          child =
              scopeManager?.buildWidgetFromDefinition(widget._controller.child);
        }
        return Container(
            decoration: widget._controller.boxDecoration, child: child);
      },
    );
  }
}
