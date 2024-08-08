import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
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
  List<String> passthroughSetters() => ['conditions'];

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

    for (var i = 1; i <= conditions.length - 1; i++) {
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

  bool _evaluateCondition(ScopeManager scopeManager, String expression) {
    try {
      final expression0 = scopeManager.dataContext.eval(expression);
      return expression0 is bool ? expression0 : false;
    } catch (e) {
      throw LanguageError('Failed to eval $expression');
    }
  }

  Widget _buildWidget(ScopeManager scopeManager, dynamic condition) {
    var widgetDefinition = YamlMap.wrap({
      condition.keys.last: condition.values.last,
    });

    if (widgetDefinition.containsKey('widget')) {
      widgetDefinition = widgetDefinition['widget'];
    }

    // Flutter tends to re-use the widgets from different if/else clause when
    // they are of the same type. Here we just stringify the widget map and use
    // them as the key, so they are guaranteed to not be re-used unless the
    // definition is identical
    return KeyedSubtree(
        key: ValueKey(widgetDefinition.toString()),
        child: scopeManager.buildWidgetFromDefinition(widgetDefinition));
  }
}
