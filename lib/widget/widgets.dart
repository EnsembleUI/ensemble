
import 'package:ensemble/widget/ensemble_widget.dart';
import 'package:flutter/cupertino.dart';


mixin UpdatableWidget<P extends Payload> on StatefulWidget {
  // all widgets can expanded inside Column/Stack
  static final _baseProperties = ['expanded'];

  // to be implemented by sub-class
  P get payload;
  @protected
  Map<String, Function> getters();
  @protected
  Map<String, Function> setters();

  List<String> getSettableProperties() {
    List<String> rtn = setters().keys.toList();
    rtn.addAll(_baseProperties);
    return rtn;
  }
  List<String> getGettableProperties() {
    List<String> rtn = getters().keys.toList();
    rtn.addAll(_baseProperties);
    return rtn;
  }
  void setProperty(String key, dynamic value) {
    if (getSettableProperties().contains(key)) {
      // base properties
      if (_baseProperties.contains(key)) {
        setBaseProperty(key, value);
      } else {
        setters()[key]!(value);
      }
      payload.dispatchChanges();
    }
  }
  dynamic getProperty(String key) {
    if (getGettableProperties().contains(key)) {
      // base properties
      if (_baseProperties.contains(key)) {
        return getBaseProperty(key);
      }
      return getters()[key];
    }
  }

  // base properties
  bool _expanded = false;

  void setBaseProperty(String key, dynamic value) {
    switch(key) {
      case 'expanded':
        _expanded = value is bool ? value : false;
        break;
    }
  }
  dynamic getBaseProperty(String key) {
    switch(key) {
      case 'expanded':
        return _expanded;
    }
    return null;
  }

}

abstract class Payload extends ChangeNotifier {
  bool expanded = false;

  void dispatchChanges() {
    notifyListeners();
  }
}

abstract class EnsembleWidgetState<W extends UpdatableWidget> extends State<W> {
  void changeState() {
    setState(() {

    });
  }

  @override
  void initState() {
    super.initState();
    widget.payload.addListener(changeState);
  }
  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.payload.removeListener(changeState);
    widget.payload.addListener(changeState);
  }
  @override
  void dispose() {
    super.dispose();
    widget.payload.removeListener(changeState);
  }
}
