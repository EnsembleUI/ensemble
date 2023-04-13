import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

import '../framework/scope.dart';

class Conditional extends StatefulWidget
    with Invokable, HasController<ConditionalController, ConditionalState> {
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
      'conditions': (value) => _controller.conditions = value,
    };
  }
}

class ConditionalController extends WidgetController {
  dynamic conditions;
}

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ConditionalState extends WidgetState<Conditional> {
  @override
  Widget buildWidget(BuildContext context) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    final conditions = widget._controller.conditions;

    if (hasStructure(scopeManager, conditions)) {
      return _buildConditionalWidget(scopeManager!, conditions);
    }

    return const SizedBox.shrink();
  }

  bool hasStructure(ScopeManager? scopeManager, dynamic conditions) {
    try {
      return scopeManager != null &&
          conditions != null &&
          (conditions is YamlList) &&
          conditions.isNotEmpty &&
          conditions.first.containsKey('if') &&
          conditions.first.containsKey('then');
    } on Exception catch (_) {
      throw LanguageError(
          'In Proper structure, make sure atleast if then condition ');
    }
  }

  Widget _buildConditionalWidget(
      ScopeManager scopeManager, dynamic conditions) {
    if (_evaluateCondition(scopeManager, conditions.first['if'])) {
      return scopeManager.buildWidgetFromDefinition(conditions.first['then']);
    }

    for (var i = 1; i < conditions.length - 1; i++) {
      final condition = conditions[i];

      if (condition.containsKey('elif') &&
          _evaluateCondition(scopeManager, condition['elif'])) {
        if (condition.containsKey('then')) {
          return scopeManager.buildWidgetFromDefinition(condition['then']);
        }
      }
    }

    if (conditions.last.containsKey('else')) {
      return scopeManager.buildWidgetFromDefinition(conditions.last['else']);
    }

    return const SizedBox.shrink();
  }

  bool _evaluateCondition(ScopeManager scopeManager, String expression) {
    try {
      return scopeManager.dataContext.eval(expression);
    } catch (e) {
      throw LanguageError('Failed to eval $expression');
    }
  }
}
