import 'dart:convert';
import 'dart:developer';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablemap.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:flutter/cupertino.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/parser/ast.dart';
import 'package:ensemble_ts_interpreter/parser/js_interpreter.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:yaml/yaml.dart';

/// manages Data and Invokables within the current data scope.
/// This class can evaluate expressions based on the data scope
class DataContext {
  final Map<String, dynamic> _contextMap = {};
  final BuildContext buildContext;

  DataContext({required this.buildContext, Map<String, dynamic>? initialMap}) {
    if (initialMap != null) {
      _contextMap.addAll(initialMap);
    }
    _contextMap['ensemble'] = NativeInvokable(buildContext);
    _contextMap['device'] = DeviceInfoInvokable();
  }

  DataContext clone({BuildContext? newBuildContext}) {
    return DataContext(buildContext: newBuildContext ?? buildContext, initialMap: _contextMap);
  }

  /// copy over the additionalContext,
  /// skipping over duplicate keys if replaced is false
  void copy(DataContext additionalContext, {bool replaced = false}) {
    // copy all fields if replaced is true
    if (replaced) {
      _contextMap.addAll(additionalContext._contextMap);
    }
    // iterate and skip duplicate
    else {
      additionalContext._contextMap.forEach((key, value) {
        if (_contextMap[key] == null) {
          _contextMap[key] = value;
        }
      });
    }
  }


  // raw data (data map, api result), traversable with dot and bracket notations
  void addDataContext(Map<String, dynamic> data) {
    _contextMap.addAll(data);
  }
  void addDataContextById(String id, dynamic value) {
    if (value != null) {
      _contextMap[id] = value;
    }
  }
  /// invokable widget, traversable with getters, setters & methods
  /// Note that this will change a reference to the object, meaning the
  /// parent scope will not get the changes to this.
  /// Make sure the scope is finalized before creating child scope, or
  /// should we just travel up the parents and update their references??
  void addInvokableContext(String id, Invokable widget) {
    _contextMap[id] = widget;
  }

  bool hasContext(String id) {
    return _contextMap[id] != null;
  }

  /// return the data context value given the ID
  dynamic getContextById(String id) {
    return _contextMap[id];
  }


  /// evaluate single inline binding expression (getters only) e.g ${myVar.text}.
  /// Note that this expects the variable to be surrounded by ${...}
  dynamic eval(dynamic expression) {
    if (expression is YamlMap) {
      return _evalMap(expression);
    }
    if ( expression is List ) {
      return _evalList(expression);
    }
    if (expression is! String) {
      return expression;
    }

    // execute as code if expression is AST
    if (expression.startsWith("//@code")) {
      return evalCode(expression);
    }

    // if just have single standalone expression, return the actual type (e.g integer)
    RegExpMatch? simpleExpression = Utils.onlyExpression.firstMatch(expression);
    if (simpleExpression != null) {
      return evalVariable(simpleExpression.group(1)!);
    }
    // if we have multiple expressions, or mixing with text, return as String
    // greedy match anything inside a $() with letters, digits, period, square brackets.
    return expression.replaceAllMapped(Utils.containExpression,
            (match) => evalVariable("${match[1]}").toString());

    /*return replaceAllMappedAsync(
        expression,
        RegExp(r'\$\(([a-z_-\d."\(\)\[\]]+)\)', caseSensitive: false),
        (match) async => (await evalVariable("${match[1]}")).toString()
    );*/

  }
  List _evalList(List list) {
    List value = [];
    for (var i in list) {
      value.add(eval(i));
    }
    return value;
  }
  Map<String, dynamic> _evalMap(YamlMap yamlMap) {
    Map<String, dynamic> map = {};
    yamlMap.forEach((k, v) {
      dynamic value;
      if (v is YamlMap) {
        value = _evalMap(v);
      } else if (v is YamlList) {
        value = _evalList(v);
      } else {
        value = eval(v);
      }
      map[k] = value;
    });
    return map;
  }


  Future<String> replaceAllMappedAsync(String string, Pattern exp, Future<String> Function(Match match) replace) async {
    StringBuffer replaced = StringBuffer();
    int currentIndex = 0;
    for(Match match in exp.allMatches(string)) {
      String prefix = match.input.substring(currentIndex, match.start);
      currentIndex = match.end;
      replaced
        ..write(prefix)
        ..write(await replace(match));
    }
    replaced.write(string.substring(currentIndex));
    return replaced.toString();
  }

  /// evaluate Typescript code block
  dynamic evalCode(String codeBlock) {
    // code can have //@code <expression>
    // We don't use that here but we need to strip
    // that out before parsing the content as JSON
    String? codeWithoutComments = Utils.codeAfterComment.firstMatch(codeBlock)?.group(1);
    if (codeWithoutComments != null) {
      codeBlock = codeWithoutComments;
    }

    final json = jsonDecode(codeBlock);
    List<ASTNode> arr = ASTBuilder().buildArray(json['body']);
    try {
      _contextMap['getStringValue'] = Utils.optionalString;
      dynamic rtnValue = Interpreter(_contextMap).evaluate(arr);
      return rtnValue;
    } catch (error) {
      // show this error? it may be considered a normal condition as
      // binding depending on API may not resolved until later e.g myAPI.value.prettyDateTime()

      return null;
    }
  }

  /// eval single line Typescript surrounded by $(...)
  dynamic evalSingleLineCode(String codeWithNotation) {
    RegExpMatch? simpleExpression = Utils.onlyExpression.firstMatch(codeWithNotation);
    if (simpleExpression != null) {
      String code = evalVariable(simpleExpression.group(1)!);
      return evalCode(code);
    }
    return null;
  }

  dynamic evalToken(List<String> tokens, int index, dynamic data) {
    // can't go further, return data
    if (index == tokens.length) {
      return data;
    }

    if (data is Map) {
      return evalToken(tokens, index+1, data[tokens[index]]);
    } else {

      // if data is a primitive, convert them to primitive Invokables so
      // we can operate on them further
      dynamic primitive = InvokablePrimitive.getPrimitive(data);
      if (primitive != null) {
        data = primitive;
      }

      if (data is Invokable) {
        String token = tokens[index];
        if (data.getGettableProperties().contains(token)) {
          return evalToken(tokens, index + 1, data.getProperty(token));
        } else {
          // only support methods with 0 or 1 argument for now
          RegExpMatch? match = RegExp(
              r'''([a-zA-Z_-\d]+)\s*\(["']?([a-zA-Z_-\d:.]*)["']?\)''')
              .firstMatch(token);
          if (match != null) {
            // first group is the method name, second is the argument
            Function? method = data.getMethods()[match.group(1)];
            if (method != null) {
              // our match will always have 2 groups. Second group is the argument
              // which could be empty since we use ()*
              List<String> args = [];
              if (match.group(2)!.isNotEmpty) {
                args.add(match.group(2)!);
              }
              dynamic nextData = Function.apply(method, args);
              return evalToken(tokens, index + 1, nextData);
            }
          }
          // return null since we can't find any matching methods/getters on this Invokable
          return null;
        }
      }
    }

    return data;
  }


  /// evaluate a single variable expression e.g myVariable.value.
  /// Note: use eval() if your variable are surrounded by $(...)
  dynamic evalVariable(String variable) {
    List<String> tokens = variable.split('.');
    dynamic result = evalToken(tokens, 1, _contextMap[tokens[0]]);
    return result;
  }

  /// token format: result
  static dynamic _parseToken(List<String> tokens, int index, Map<String, dynamic> map) {
    if (index == tokens.length-1) {
      return map[tokens[index]];
    }
    if (map[tokens[index]] == null) {
      return null;
    }
    return _parseToken(tokens, index+1, map[tokens[index]]);
  }


}

class DeviceInfoInvokable with Invokable {
  @override
  Map<String, Function> getters() {
    DeviceInfo deviceInfo = Ensemble().deviceInfo;
    return {
      "width": () => deviceInfo.size.width,
      "height": () => deviceInfo.size.height,
      "platform": () => deviceInfo.platform.name,
      DevicePlatform.web.name: () => DeviceWebInfo()
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }


}

class DeviceWebInfo with Invokable {
  @override
  Map<String, Function> getters() {
    WebBrowserInfo? browserInfo = Ensemble().deviceInfo.browserInfo;
    return {
      'browserName': () => browserInfo?.browserName == null ? null : describeEnum(browserInfo!.browserName),
      'appCodeName': () => browserInfo?.appCodeName,
      'appName': () => browserInfo?.appName,
      'appVersion': () => browserInfo?.appVersion,
      'deviceMemory': () => browserInfo?.deviceMemory,
      'language': () => browserInfo?.language,
      'languages': () => browserInfo?.languages,
      'platform': () => browserInfo?.platform,
      'product': () => browserInfo?.product,
      'productSub': () => browserInfo?.productSub,
      'userAgent': () => browserInfo?.userAgent,
      'vendor': () => browserInfo?.vendor,
      'vendorSub': () => browserInfo?.vendorSub,
      'hardwareConcurrency': () => browserInfo?.hardwareConcurrency,
      'maxTouchPoints': () => browserInfo?.maxTouchPoints,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}


/// built-in helpers/utils accessible to all DataContext
class NativeInvokable with Invokable {
  final BuildContext _buildContext;
  NativeInvokable(this._buildContext);

  @override
  Map<String, Function> getters() {
    return {
      'storage': () => EnsembleStorage(),
      'formatter': () => Formatter(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      ActionType.navigateScreen.name: navigateToScreen,
      ActionType.showModalScreen.name: showModalScreen,
      ActionType.invokeAPI.name: invokeAPI,
      'debug': (value) => log('Debug: $value'),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  void navigateToScreen(String screenId, [dynamic inputs]) {
    Map<String, dynamic>? inputMap = Utils.getMap(inputs);
    Ensemble().navigateApp(
      _buildContext,
      screenName: screenId,
      pageArgs: inputMap,
      asModal: false);
  }
  void showModalScreen(String screenId, [dynamic inputs]) {
    Map<String, dynamic>? inputMap = Utils.getMap(inputs);
    Ensemble().navigateApp(
      _buildContext,
      screenName: screenId,
      pageArgs: inputMap,
      asModal: true);
    // how do we handle onModalDismiss in Typescript?
  }
  void invokeAPI(String apiName, [dynamic inputs]) {
    Map<String, dynamic>? inputMap = Utils.getMap(inputs);
    ScreenController().executeAction(_buildContext, InvokeAPIAction(
      apiName: apiName,
      inputs: inputMap
    ));
  }

}

/// Singleton handling user storage
class EnsembleStorage with Invokable {
  static final EnsembleStorage _instance = EnsembleStorage._internal();
  EnsembleStorage._internal();
  factory EnsembleStorage() {
    return _instance;
  }
  // TODO: use async secure storage - extends FlutterSecureStorage
  final Map<String, dynamic> userStorage = {};

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'get': (String key) => userStorage[key],
      'set': (String key, dynamic value) {
        if (value != null) {
          userStorage[key] = value;
        }
      }
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}

class Formatter with Invokable {
  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'prettyDate': (input) => InvokablePrimitive.prettyDate(input),
      'prettyDateTime': (input) => InvokablePrimitive.prettyDateTime(input),
      'prettyCurrency': (input) => InvokablePrimitive.prettyCurrency(input),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}

class APIResponse with Invokable {
  Response? _response;
  APIResponse({Response? response}) {
    if (response != null) {
      setAPIResponse(response);
    }
  }

  setAPIResponse(Response response) {
    _response = response;
  }

  @override
  Map<String, Function> getters() {
    return {
      'body': () => _response?.body,
      'headers': () => _response?.headers
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

}