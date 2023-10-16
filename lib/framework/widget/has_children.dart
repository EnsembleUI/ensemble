import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

mixin HasChildren<W extends HasController> on WidgetState<W> {
  List<Widget> buildChildren(List<WidgetModel> models,
      {ScopeManager? preferredScopeManager}) {
    if (preferredScopeManager != null || scopeManager != null) {
      return models
          .map((model) =>
              (preferredScopeManager ?? scopeManager)!.buildWidget(model))
          .toList();
    }
    return [];
  }

  Widget buildChild(WidgetModel model) {
    if (scopeManager == null) {
      throw RuntimeError("scopeManager is null while building its child");
    }
    return scopeManager!.buildWidget(model);
  }
}
