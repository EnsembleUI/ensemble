import 'package:ensemble/framework/action.dart' as action;
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensemble;
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

/// base mixin for Ensemble Container (e.g Column)
mixin UpdatableContainer<T extends Widget> {
  void initChildren({List<T>? children, ItemTemplate? itemTemplate});
}

/// base class for widgets that want to participate in Ensemble layout
abstract class WidgetState<W extends HasController> extends BaseWidgetState<W> {
  ScopeManager? _scopeManager;

  @override
  Widget build(BuildContext context) {
    if (widget.controller is WidgetController) {
      if (!(widget.controller as WidgetController).visible) {
        return const SizedBox.shrink();
      }
      Widget rtn = buildWidget(context);

      // wrap inside Align if specified
      if ((widget.controller as WidgetController).alignToParent != null) {
        rtn = Align(
            alignment: (widget.controller as WidgetController).alignToParent!,
            child: rtn);
      }

      if ((widget.controller as WidgetController).expanded == true) {
        /// Important notes:
        /// 1. If the Column/Row is scrollable, putting Expanded on the child will cause layout exception
        /// 2. If Column/Row is inside a parent without height/width constraint, it will collapse its size.
        ///    So if we put Expanded on the Column's child, layout exception will occur
        rtn = Expanded(child: rtn);
      }

      return rtn;
    }
    throw LanguageError("Wrong usage of widget controller!");
  }

  /// build your widget here
  Widget buildWidget(BuildContext context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scopeManager = DataScopeWidget.getScope(context);
  }

  @override
  void changeState() {
    super.changeState();
    // dispatch changes, so anything binding to this will be notified
    if (widget.controller.lastSetterProperty != null) {
      if (_scopeManager != null &&
          widget is Invokable &&
          (widget as Invokable).id != null) {
        _scopeManager!.dispatch(ModelChangeEvent(
            WidgetBindingSource((widget as Invokable).id!,
                property: widget.controller.lastSetterProperty!.key),
            widget.controller.lastSetterProperty!.value));
      }
      widget.controller.lastSetterProperty = null;
    }
  }
}

/// some of our widgets use LayoutBuilder to detect if their parent has
/// infinite width/height to properly respond (Input widgets inside Row
/// requires expanded=true). However some container (e.g. DataTable) requires
/// all its children to return the intrinsic width/height to properly render.
/// We just need to expose the hierarchy chain so we can properly handle
/// various situations
class RequiresChildWithIntrinsicDimension extends InheritedWidget {
  const RequiresChildWithIntrinsicDimension({super.key, required super.child});

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) {
    return false;
  }
}
