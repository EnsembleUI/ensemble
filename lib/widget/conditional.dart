import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
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

class ConditionalState extends WidgetState<Conditional> {
  Widget? _widget;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager == null) return;

    final conditions = widget._controller.conditions;
    if (!hasProperStructure(conditions)) return;

    List<String> expressions = [];

    expressions.add(conditions.first['if']);

    for (var condition in conditions) {
      if (condition.containsKey('elseif')) {
        expressions.add(condition['elseif']);
      }
    }

    for (var expression in expressions) {
      scopeManager.listen(
        scopeManager,
        expression,
        destination: BindingDestination(widget, 'conditions'),
        onDataChange: (event) {
          if (mounted) {
            setState(() {
              _widget = _buildConditionalWidget(scopeManager, conditions);
            });
          }
        },
      );
    }
    if (mounted) {
      setState(() {
        _widget = _buildConditionalWidget(scopeManager, conditions);
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    return _widget ?? const SizedBox.shrink();
  }

  bool hasProperStructure(dynamic conditions) {
    try {
      return conditions != null &&
          (conditions is YamlList) &&
          conditions.isNotEmpty &&
          conditions.first.containsKey('if');
    } on Exception catch (_) {
      throw LanguageError(
          'Improper structure, make sure atleast if condition is present ');
    }
  }

  Widget? _buildConditionalWidget(
      ScopeManager scopeManager, dynamic conditions) {
    if (_evaluateCondition(scopeManager, conditions.first['if'])) {
      return _buildWidget(scopeManager, conditions.first);
    }

    final elseIfCount = getElseIfCount(scopeManager, conditions);
    final conditionCount =
        elseIfCount == 1 ? conditions.length : conditions.length - 1;
    for (var i = 1; i < conditionCount; i++) {
      final condition = conditions[i];

      if (condition.containsKey('elseif') &&
          _evaluateCondition(scopeManager, condition['elseif'])) {
        return _buildWidget(scopeManager, condition);
      }
    }

    if (conditions.last.containsKey('else')) {
      return _buildWidget(scopeManager, conditions.last);
    }

    return null;
  }

  int getElseIfCount(ScopeManager scopeManager, dynamic conditions) {
    int elseIfCount = conditions
        .map((element) => element['elseif'] != null &&
                _evaluateCondition(scopeManager, element['elseif'])
            ? 1
            : 0)
        .reduce((value, element) => value + element);
    return elseIfCount;
  }

  bool _evaluateCondition(ScopeManager scopeManager, String expression) {
    try {
      final _expression = scopeManager.dataContext.eval(expression);
      return _expression is bool ? _expression : false;
    } catch (e) {
      throw LanguageError('Failed to eval $expression');
    }
  }

  Widget _buildWidget(ScopeManager scopeManager, dynamic condition) {
    final widgetDefination = YamlMap.wrap({
      condition.keys.last: condition.values.last,
    });

    return scopeManager.buildWidgetFromDefinition(widgetDefination);
  }
}
