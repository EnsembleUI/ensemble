import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../framework/scope.dart';

class Conditional extends StatefulWidget with Invokable, HasController<ConditionalController, ConditionalState> {
  static const type = 'Conditional';
  Conditional({Key? key}) : super(key: key);

  final ConditionalController _controller = ConditionalController();
  @override
  ConditionalController get controller => _controller;

  @override
  State<StatefulWidget> createState() => ConditionalState();

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
      'if': (value) => _controller.ifCondition = value,
      'then': (value) => _controller.then = value,
    };
  }

}

class ConditionalController extends WidgetController {
  bool? ifCondition;
  dynamic then;
}

class ConditionalState extends WidgetState<Conditional> {

  Widget? thenWidget;

  @override
  void didChangeDependencies() {
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    thenWidget = parentScope?.buildWidgetFromDefinition(widget.controller.then);
  
    super.didChangeDependencies();
  }

  @override
  Widget buildWidget(BuildContext context) {
    if ((widget._controller.ifCondition ?? false) && thenWidget != null) {
      return thenWidget!;
    }
    return const SizedBox.shrink();
  }
}
