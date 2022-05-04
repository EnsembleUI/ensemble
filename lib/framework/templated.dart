
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// mixin for Widget that supports item-template
mixin TemplatedWidgetState {

  void registerItemTemplate(BuildContext context, ItemTemplate itemTemplate, {required Function onDataChanged}) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      // find the source and the property to bind to
      // data: $(apiName.*)
      String expression = itemTemplate.data.substring(2, itemTemplate.data.length-1);
      int dotIndex = expression.indexOf('.');
      if (dotIndex != -1) {
        String modelId = expression.substring(0, dotIndex);
        dynamic bindingSource = scopeManager.dataContext.getContextById(modelId);

        // only Invokable is bind-able

        if (bindingSource is APIResponse) {
          scopeManager.listen(modelId, (ModelChangeEvent event) {
            // evaluate the expression
            dynamic dataList = scopeManager.dataContext.eval(itemTemplate.data);
            if (dataList is List) {
              onDataChanged(dataList);
            }
          });
        } else if (bindingSource is Invokable) {

          // TODO

        }



      }


    }
  }

  /// build the list of templated widget from the given data expression
  List<Widget>? buildItemsFromTemplate(BuildContext context, List dataList, ItemTemplate itemTemplate) {
    List<Widget>? widgets;
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    if (parentScope != null) {
      widgets = [];
      for (dynamic itemData in dataList) {
        // create a new scope for each item template
        ScopeManager templatedScope = parentScope.createChildScope();
        templatedScope.dataContext.addDataContextById(itemTemplate.name, itemData);

        Widget templatedWidget = templatedScope.buildWidgetFromDefinition(itemTemplate.template);

        // wraps each templated widget inside a DataScopeWidget so
        // we can constraint the data scope
        widgets.add(DataScopeWidget(scopeManager: templatedScope, child: templatedWidget));
      }
    }
    return widgets;
  }


}