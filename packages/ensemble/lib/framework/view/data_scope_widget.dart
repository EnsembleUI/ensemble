import 'package:ensemble/framework/scope.dart';
import 'package:flutter/cupertino.dart';

/// a wrapper InheritedWidget to expose the ScopeManager
/// to every widgets in our tree
class DataScopeWidget extends InheritedWidget {
  const DataScopeWidget(
      {super.key, required this.scopeManager, required super.child});

  final ScopeManager scopeManager;

  @override
  bool updateShouldNotify(DataScopeWidget oldWidget) {
    return oldWidget.scopeManager != scopeManager;
  }

  /// return the ScopeManager which includes the dataContext
  static ScopeManager? getScope(BuildContext context) {
    DataScopeWidget? viewWidget =
        context.dependOnInheritedWidgetOfExactType<DataScopeWidget>();
    if (viewWidget != null) {
      return viewWidget.scopeManager;
    }
    return null;
  }
}
