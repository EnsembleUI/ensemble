import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/widgets.dart';
import 'package:source_span/source_span.dart';

mixin Invokable {
  // optional ID to identify this Invokable
  String? id;
  SourceSpan? definition;
  /// mark these functions as protected as we need the implementations,
  /// but discourage direct usages.
  /// Reasons:
  ///  1. There are more base getters/setters/methods from the base class.
  ///     Users can just focus on defining only applicable fields for their
  ///     classes but still get the base implementations automatically.
  ///  2. setProperty() will automatically notify the controller's listeners
  ///     for changes, enabling the listeners (widget state) to redraw.
  ///
  /// Use getProperty/setProperty/callMethod instead of these.
  Map<String, Function> getters();
  Map<String, Function> setters();
  Map<String, Function> methods();

  List? getList(Object obj) {
    List? l;
    if ( obj is List ) {
      l = obj;
    }
    return l;
  }
  String? getString(Object obj) {
    String? str;
    if ( obj is String ) {
      str = obj;
    } else if ( obj is Map && obj.containsKey('value') ) {
      str = obj['value'] as String;
    }
    return str;
  }
  Map? getMap(Object obj) {
    Map? m;
    if ( obj is Map ) {
      m = obj;
    }
    return m;
  }
  static List<String> getGettableProperties(Invokable obj) {
    List<String> rtn = obj.getters().keys.toList();
    if (obj is HasController) {
      rtn.addAll((obj as HasController).controller.getBaseGetters().keys);
    }
    return rtn;
  }

  static List<String> getSettableProperties(Invokable obj) {
    List<String> rtn = obj.setters().keys.toList();
    if (obj is HasController) {
      rtn.addAll((obj as HasController).controller.getBaseSetters().keys);
    }
    return rtn;
  }

  static Map<String, Function> getMethods(Invokable obj) {
    Map<String, Function> rtn = obj.methods();
    if (obj is HasController) {
      rtn.addAll((obj as HasController).controller.getBaseMethods());
    }
    return rtn;
  }
  bool hasSettableProperty(dynamic prop) {
    return getSettableProperties(this).contains(prop);
  }
  bool hasGettableProperty(dynamic prop) {
    return getGettableProperties(this).contains(prop);
  }
  Function? getMethod(dynamic method) {
    Map<String, Function> rtn = getMethods(this);
    if (rtn.containsKey(method)) {
      return rtn[method];
    }
    return null;
  }
  bool hasMethod(dynamic method) {
    return getMethods(this).containsKey(method);
  }
  dynamic getProperty(dynamic prop) {
    Function? func = getters()[prop];
    if (func == null && this is HasController) {
      func = (this as HasController).controller.getBaseGetters()[prop];
    }

    if (func != null) {
      return func();
    }
    throw InvalidPropertyException('Object with id:${id??''} does not have a gettable property named $prop');
  }

  /// update a property. If this is a HasController (i.e. Widget), notify it of changes
  void setProperty(dynamic prop, dynamic val) {
    Function? func = setters()[prop];
    if (func == null && this is HasController) {
      func = (this as HasController).controller.getBaseSetters()[prop];
    }

    if (func != null) {
      func(val);

      // ask our controller to notify its listeners of changes
      if (this is HasController) {
        (this as HasController).controller.dispatchChanges(KeyValue(prop.toString(), val));
      } else if (this is EnsembleController) {
        (this as EnsembleController).notifyListeners();
      }

    } else {
      throw InvalidPropertyException('Object with id:${id??''} does not have a settable property named $prop');
    }
  }
}

/// Base Mixin for Widgets that want to participate in Ensemble widget tree.
/// This works in conjunction with Controller and WidgetState
mixin HasController<C extends Controller, S extends WidgetStateMixin> on StatefulWidget{
  C get controller;

  /// a widget can tell the framework not to automatically evaluate its value
  /// while calling the setters can include the passthrough list here.
  /// This is useful if the widget wants to evaluate the value later (e.g.
  /// evaluate an Action's variables upon the action execution), or it wants
  /// to handle the binding listeners itself (e.g. item-template like)
  List<String> passthroughSetters() => [];
}

abstract class EnsembleController extends ChangeNotifier with Invokable {

}

abstract class Controller extends ChangeNotifier {
  KeyValue? lastSetterProperty;

  // notify listeners of changes
  void dispatchChanges(KeyValue changedProperty) {
    lastSetterProperty = changedProperty;
    notifyListeners();
  }

  // your controllers may want to extend these to provide base implementations
  Map<String, Function> getBaseGetters() {
    return {};
  }
  Map<String, Function> getBaseSetters() {
    return {};
  }
  Map<String, Function> getBaseMethods() {
    return {};
  }
}

/// purely for type checking so WidgetState implementation
/// has the correct type
mixin WidgetStateMixin {
}

/// base state for Flutter widgets that want to be of Invokable type
abstract class BaseWidgetState<W extends HasController> extends State<W> with WidgetStateMixin {
  void changeState() {
    // trigger widget to rebuild
    setState(() {

    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(changeState);
  }
  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(changeState);
    widget.controller.addListener(changeState);
  }
  @override
  void dispose() {
    super.dispose();
    widget.controller.removeListener(changeState);
  }


}

class KeyValue {
  KeyValue(this.key, this.value);

  String key;
  dynamic value;
}
mixin SupportsPrimitiveOperations {
  //operator could be any of the primitive operators such as -, + , *, / etc
  //rhs is the right hand side
  dynamic runOperation(String operator,dynamic rhs);
}