import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/**
 * A controller that keeps track of all the RadioButtons within a page.
 * RadioButtons with the same groupId will reference the same instance of this controller
 */
class RadioButtonController extends ChangeNotifier with Invokable {
  RadioButtonController._(this.groupId, this.scopeManager);

  ScopeManager scopeManager;
  String groupId;

  // return an existing RadioButtonController that matches the groupId or create new one
  static RadioButtonController getInstance(
          String groupId, ScopeManager scopeManager) =>
      scopeManager.pageData.radioButtonControllers.putIfAbsent(
          groupId, () => RadioButtonController._(groupId, scopeManager));

  dynamic _selectedValue;

  set selectedValue(value) {
    if (value != _selectedValue) {
      _selectedValue = value;
      notifyListeners();

      // dispatch changes so any bindings to ${groupId.selectedValue} can be executed.
      scopeManager
          .dispatch(ModelChangeEvent(SimpleBindingSource(groupId), value));
    }
  }

  get selectedValue => _selectedValue;

  // use to set the initial default value without dispatching changes
  set defaultValue(value) {
    _selectedValue = value;
  }

  @override
  Map<String, Function> getters() => {'selectedValue': () => _selectedValue};

  @override
  Map<String, Function> methods() => {};

  @override
  Map<String, Function> setters() =>
      {'selectedValue': (value) => selectedValue = value};
}
