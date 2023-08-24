import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

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
      'widget': (widget) => _controller.widget = widget,
      'loadingWidget': (loadingWidget) =>
          _controller.loadingWidget = loadingWidget,
    };
  }
}

class LoadingContainerController extends BoxController {
  bool? isLoading;
  bool? useShimmer;
  dynamic widget;
  dynamic loadingWidget;
}

class LoadingContainerState extends WidgetState<LoadingContainer> {
  Widget? dataWidget;
  Widget? loadingWidget;

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget buildWidget(BuildContext context) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);

    dataWidget = _buildWidget(widget._controller.widget, scopeManager);
    loadingWidget = _buildWidget(widget._controller.widget, scopeManager);

    return BoxWrapper(
      widget: getWidget(),
      boxController: widget._controller,
      ignoresPadding: true,
      ignoresDimension:
          true, // width/height shouldn't be apply in the container
    );
  }

  Widget getWidget() {
    if (widget._controller.isLoading != null && widget._controller.isLoading!) {
      return loadingWidget ?? const CircularProgressIndicator();
    }
    return dataWidget ?? const SizedBox.shrink();
  }

  Widget? _buildWidget(dynamic widgetDefinition, ScopeManager? scopeManager) {
    if (scopeManager != null && widgetDefinition != null) {
      return scopeManager.buildWidgetFromDefinition(widgetDefinition);
    }
    return null;
  }
}
