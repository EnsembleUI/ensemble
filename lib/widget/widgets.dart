import 'package:ensemble/util/utils.dart';
import 'package:flutter/cupertino.dart';

/// base mixin for widgets to be used with Ensemble
mixin UpdatableWidget<C extends WidgetController, S extends WidgetState> on StatefulWidget {

  List<String> getSettableProperties() {
    List<String> rtn = setters().keys.toList();
    rtn.addAll(controller.getBaseSetters().keys);
    return rtn;
  }
  List<String> getGettableProperties() {
    List<String> rtn = getters().keys.toList();
    rtn.addAll(controller.getBaseGetters().keys);
    return rtn;
  }
  void setProperty(String key, dynamic value) {
    Map<String, Function> props = controller.getBaseSetters();
    props.addAll(setters());
    if (props.containsKey(key)) {
      props[key]!(value);
      controller.dispatchChanges();
    }
  }
  dynamic getProperty(String key) {
    Map<String, Function> props = controller.getBaseGetters();
    props.addAll(getters());
    if (props.containsKey(key)) {
      return props[key]!();
    }
  }

  /// make sure the same controller instance is
  /// returned when calling this multiple times
  C get controller;

  @protected
  Map<String, Function> getters();
  @protected
  Map<String, Function> setters();

}

/// purely for type checking so WidgetState implementation
/// has the correct type
mixin WidgetState<W> {
}

/// base class for your Widget State
abstract class EnsembleWidgetState<W extends UpdatableWidget> extends State<W> with WidgetState<W> {
  void changeState() {
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

/// base Controller class for your Ensemble widget
abstract class WidgetController extends ChangeNotifier {

  // Note: we manage these here so the user doesn't need to do in their widgets
  // base properties applicable to all widgets
  bool expanded = false;
  //int? padding;

  /// ask the widget to rebuild itself
  void dispatchChanges() {
    notifyListeners();
  }

  Map<String, Function> getBaseGetters() {
    return {
      'expanded': () => expanded,
      //'padding': () => padding,
    };
  }

  Map<String, Function> getBaseSetters() {
    return {
      'expanded': (value) => expanded = value is bool ? value : false,
      //'padding': (value) => padding = Utils.optionalInt(value),
    };
  }
}

/// Controls attributes applicable for all Form Field widgets.
class FormFieldController extends WidgetController {
  bool enabled = true;
  bool required = false;
  String? label;
  String? hintText;

  Map<String, Function> getters() {
    return {
      'enabled': () => enabled,
      'required': () => required,
      'label': () => label,
      'hintText': () => hintText,
    };
  }

  Map<String, Function> setters() {
    return {
      'enabled': (value) => enabled = value is bool ? value : true,
      'required': (value) => required = value is bool ? value : false,
      'label': (value) => label = Utils.optionalString(value),
      'hintText': (value) => hintText = Utils.optionalString(value),
    };
  }

}