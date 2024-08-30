import 'dart:developer';

import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/data_utils.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/theme_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// mixin for Widget that supports item-template
mixin TemplatedWidgetState<W extends StatefulWidget> on State<W> {
  void registerItemTemplate(BuildContext context, BaseItemTemplate itemTemplate,
      {required Function onDataChanged}) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);

    if (scopeManager != null) {
      DataExpression? dataExpression =
          DataUtils.parseDataExpression(itemTemplate.data);
      if (dataExpression != null) {
        // listen to the binding from our itemTemplate
        // data: $(apiName.*)
        scopeManager.listen(scopeManager, dataExpression.rawExpression,
            destination: (widget is EnsembleWidget)
                ? BindingDestination(
                    (widget as EnsembleWidget).controller, 'itemTemplate')
                : BindingDestination(widget as Invokable, 'itemTemplate'),
            onDataChange: (ModelChangeEvent event) {
          // Optimization - we don't care if API status is in loading state
          if (event.source is APIBindingSource &&
              event.payload is APIResponse &&
              event.payload.isLoading()) {
            return;
          }
          // evaluate the expression
          dynamic dataList = scopeManager.dataContext.eval(itemTemplate.data);
          if (dataList is List) {
            onDataChanged(dataList);
          }
        });
      }

      // evaluate the data list now and dispatch it as a data change
      dynamic dataList = scopeManager.dataContext.eval(itemTemplate.data);
      if (dataList is List) {
        onDataChanged(dataList);
      } else {
        // TODO: evaluate the initial values here? No use case yet
        // dynamic initialValue =
        //     scopeManager.dataContext.eval(itemTemplate.initialValue);
        // if (initialValue is List) {
        //   onDataChanged(initialValue);
        // }
      }
    }
  }

  List<DataScopeWidget>? buildWidgetsFromTemplate(
      BuildContext context, List dataList, ItemTemplate itemTemplate) {
    List<DataScopeWidget>? widgets;
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    if (parentScope != null) {
      widgets = [];
      final modelPath = "/$hashCode";
      // final modelPath = '';
      for (var i=0; i<dataList.length; i++) {
        final itemData = dataList[i];
        DataScopeWidget singleWidget =
            buildSingleWidget(parentScope, itemTemplate, itemData, modelPath: '$modelPath/itemTemplate[$i]');
        widgets.add(singleWidget);
      }
    }
    return widgets;
  }

  DataScopeWidget buildSingleWidget(
      ScopeManager parentScope, ItemTemplate itemTemplate, dynamic itemData,
      {Key? key, String? modelPath}) {
    // create a new scope for each item template
    ScopeManager templatedScope = parentScope.createChildScope();
    templatedScope.dataContext.addDataContextById(itemTemplate.name, itemData);
    WidgetModel model =
        templatedScope.buildModelFromDefinition(itemTemplate.template, modelPath);
    model.useCache = false;
    Widget templatedWidget = templatedScope.buildWidgetFromModel(model);
    // Widget templatedWidget =
    //     templatedScope.buildWidgetFromDefinition(itemTemplate.template);

    // wraps the templated widget inside a DataScopeWidget so we can constrain the data scope
    return DataScopeWidget(
      scopeManager: templatedScope,
      child: templatedWidget,
      key: key,
    );
  }

  DataScopeWidget? buildWidgetForIndex(BuildContext context, List dataList,
      ItemTemplate itemTemplate, int itemIndex) {
    //log("building item index $itemIndex");
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    if (parentScope != null) {
      dynamic itemData = dataList.elementAt(itemIndex);
      //return buildSingleWidget(parentScope, itemTemplate, itemData, key: ValueKey(itemIndex));
      return buildSingleWidget(parentScope, itemTemplate, itemData);
    }
    return null;
  }
}
