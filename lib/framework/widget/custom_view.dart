import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

/// represent a Custom View declared in a yaml screen
class CustomView extends StatelessWidget with Invokable {
  CustomView(
      {super.key,
      required this.childWidget,
      this.parameters,
      required this.scopeManager,
      required this.viewBehavior});

  final List<String>? parameters;
  final Widget childWidget;
  final ScopeManager scopeManager;
  final ViewBehavior viewBehavior;
  bool onLoadExecuted = false;

  @override
  Widget build(BuildContext context) {
    // execute onLoad once if applicable
    if (viewBehavior.onLoad != null && !onLoadExecuted) {
      onLoadExecuted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScreenController().executeAction(context, viewBehavior.onLoad!);
      });
    }
    return childWidget;
  }

  /// override to control setting input parameters
  /// as well as dispatching changes
  @override
  void setProperty(dynamic prop, dynamic val) {
    if (prop != null && parameters != null && parameters!.contains(prop)) {
      // override the key
      if (val is Invokable) {
        scopeManager.dataContext.addInvokableContext(prop, val);
      } else {
        scopeManager.dataContext.addDataContextById(prop, val);
      }

      // dispatch the changes to all inside our Custom Widget scope
      //log("Dispatching ${prop}=${val}. Scope ${scopeManager.hashCode}");
      scopeManager.dispatch(ModelChangeEvent(SimpleBindingSource(prop), val,
          bindingScope: scopeManager));
    }
  }

  @override
  Map<String, Function> getters() {
    throw UnimplementedError();
  }

  @override
  Map<String, Function> methods() {
    throw UnimplementedError();
  }

  @override
  Map<String, Function> setters() {
    throw UnimplementedError();
  }
}
