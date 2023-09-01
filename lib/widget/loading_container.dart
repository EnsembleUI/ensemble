import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/shape.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../framework/view/page.dart';

class LoadingContainer extends StatefulWidget
    with
        Invokable,
        HasController<LoadingContainerController, LoadingContainerState> {
  static const type = 'LoadingContainer';
  LoadingContainer({Key? key}) : super(key: key);

  final LoadingContainerController _controller = LoadingContainerController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => LoadingContainerState();

  @override
  Map<String, Function> getters() {
    return {
      'isLoading': () => _controller.isLoading,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'isLoading': (value) => _controller.isLoading = Utils.optionalBool(value),
      'useShimmer': (value) =>
          _controller.useShimmer = Utils.optionalBool(value),
      'defaultShimmerPadding': (value) =>
          _controller.defaultShimmerPadding = Utils.getInsets(value),
      'widget': (widget) => _controller.widget = widget,
      'loadingWidget': (loadingWidget) =>
          _controller.loadingWidget = loadingWidget,
    };
  }
}

class LoadingContainerController extends BoxController {
  bool? isLoading;
  bool? useShimmer;
  EdgeInsets? defaultShimmerPadding;
  dynamic widget;
  dynamic loadingWidget;
}

class LoadingContainerState extends WidgetState<LoadingContainer> {
  Widget? loadingWidget;
  late Widget contentWidget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // only if specified, as loadingWidget is optional
    if (widget._controller.loadingWidget != null) {
      loadingWidget = DataScopeWidget.getScope(context)
          ?.buildWidgetFromDefinition(widget._controller.loadingWidget);
    }
    // main widget
    Widget? w = DataScopeWidget.getScope(context)
        ?.buildWidgetFromDefinition(widget._controller.widget);
    if (w == null) {
      throw RuntimeError(
          "LoadingContainer requires a widget to render it's main content");
    }
    contentWidget = w;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Stack(children: [
      // loading widget
      AnimatedOpacity(
          opacity: widget._controller.isLoading == true ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: widget._controller.useShimmer == true
              ? Shimmer.fromColors(
                  baseColor: const Color(0xFFE0E0E0),
                  highlightColor: const Color(0xFFF5F5F7).withOpacity(0.5),
                  child: loadingWidget ??
                      DefaultLoadingShape(
                          padding: widget._controller.defaultShimmerPadding))
              : loadingWidget ?? const SizedBox.shrink()),

      // fade in main content
      AnimatedOpacity(
          opacity: widget._controller.isLoading == true ? 0 : 1,
          duration: const Duration(milliseconds: 300),
          child: contentWidget)
    ]);
  }
}

/// the default loading used for shimmer
class DefaultLoadingShape extends StatelessWidget {
  const DefaultLoadingShape({super.key, this.padding});
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Padding(
      padding: padding ?? const EdgeInsets.only(top: 50, bottom: 50),
      child: const Column(
        children: [
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape(),
          SizedBox(height: 10),
          ListDetailShape()
        ],
      ));
}

class ListDetailShape extends StatelessWidget {
  const ListDetailShape({super.key});

  @override
  Widget build(BuildContext context) => const Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InternalShape(
              type: ShapeType.square,
              width: 50,
              borderRadius: BorderRadius.all(Radius.circular(10)),
              backgroundColor: Colors.white),
          SizedBox(width: 10),
          Column(
            children: [
              InternalShape(
                  type: ShapeType.rectangle,
                  width: 200,
                  height: 10,
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  backgroundColor: Colors.white),
              SizedBox(height: 10),
              InternalShape(
                  type: ShapeType.rectangle,
                  width: 200,
                  height: 5,
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                  backgroundColor: Colors.white),
            ],
          )
        ],
      );
}
