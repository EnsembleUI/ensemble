import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:jsparser/jsparser.dart';
import 'package:ensemble_ts_interpreter/errors.dart';

class DevMode {
  static bool debug = false;
  static String? screenId;
  static String? screenName;
  static DataContext? _pageDataContext;

  static DataContext? get pageDataContext => _pageDataContext;

  static set pageDataContext(DataContext? dataContext) {
    if (!debug) return;
    _pageDataContext = dataContext;
  }

  // Recursive function to process Invokable objects at any depth
  static Map<String, dynamic> processInvokable(Invokable invokable) {
    Map<String, dynamic> propMap = {};
    List<String> getters = Invokable.getGettableProperties(invokable);
    for (String getter in getters) {
      dynamic propValue = invokable.getProperty(getter);

      // Check if the property value is also an Invokable and process it recursively
      if (propValue is Invokable) {
        propValue = processInvokable(propValue);
      }

      propMap[getter] = propValue;
    }
    Map<String, Function> methods = Invokable.getMethods(invokable);
    for (String method in methods.keys) {
      Function f = methods[method]!;
      propMap[method] = 'function() {}';
    }

    return propMap;
  }

  static Map<String, dynamic> getContextAsJs(Map<String, dynamic> contextMap) {
    Map<String, dynamic> context = {};

    contextMap.forEach((key, value) {
      if (value is Invokable) {
        // Use the recursive function to process Invokable objects deeply
        Map<String, dynamic> propMap = processInvokable(value);

        // Add propMap to context only if the value is Invokable
        context[key] = propMap;
      }
      // If the value does not extend Invokable, it's not added to the context
    });

    return context;
  }

  static Map<String, dynamic> validateJsCode(String code) {
    try {
      Program p = JSInterpreter.parseCode(code);
      JSInterpreter(code, p, DevMode.pageDataContext!).validate();
      return {'error': null};
    } on JSException catch (e) {
      return {'error': e.toString()};
    } catch (e) {
      return {'error': e.toString()};
    }
  }
}
