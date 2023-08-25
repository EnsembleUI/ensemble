import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';

import '../framework/view/page.dart';

class Box extends StatefulWidget
    with Invokable, HasController<BoxContainerController, BoxState> {
  static const type = 'Box';
  Box({Key? key}) : super(key: key);

  final BoxContainerController _controller = BoxContainerController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => BoxState();

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
      'widget': (widget) => _controller.widget = widget,
    };
  }
}

class BoxContainerController extends BoxController {
  dynamic widget;
}

class BoxState extends WidgetState<Box> {
  @override
  Widget buildWidget(BuildContext context) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);

    return BoxWrapper(
      widget: _buildWidget(widget._controller.widget, scopeManager),
      boxController: widget._controller,
      ignoresPadding: false,
      ignoresDimension: false,
    );
  }

  Widget _buildWidget(dynamic widgetDefinition, ScopeManager? scopeManager) {
    if (scopeManager != null && widgetDefinition != null) {
      return scopeManager.buildWidgetFromDefinition(widgetDefinition);
    }
    return const SizedBox();
  }
}
