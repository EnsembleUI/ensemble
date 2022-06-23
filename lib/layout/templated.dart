
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/view.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// mixin for Widget that supports item-template
mixin TemplatedWidgetState<W extends StatefulWidget> on State<W> {

  void registerItemTemplate(BuildContext context, ItemTemplate itemTemplate, {required Function onDataChanged}) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    DataExpression? dataExpression = Utils.parseDataExpression(itemTemplate.data);
    if (scopeManager != null && dataExpression != null) {




      // listen to the binding from our itemTemplate
      // data: $(apiName.*)
      scopeManager.listen(dataExpression.rawExpression, me: (widget as Invokable), onDataChange:(ModelChangeEvent event) {
        // evaluate the expression
        dynamic dataList = scopeManager.dataContext.eval(itemTemplate.data);
        if (dataList is List) {
          onDataChanged(dataList);
        }
      });
    }
  }

  /// build the list of templated widget from the given data expression
  /// Note that each child is wrapped in DataScopeWidget for proper data scoping
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