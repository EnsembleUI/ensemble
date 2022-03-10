class Utils {

  /// evaluate an expression from the given daaMap
  /// e.g Hello $(name.first) -> Hello Peter
  static dynamic evalExpression(dynamic expression, Map<String, dynamic>? dataMap) {
    if (dataMap == null || expression is! String) {
      return expression;
    }
    // if just have single standalone expression, return the actual type (e.g integer)
    RegExpMatch? simpleExpression = RegExp(r'^\$\(([a-z_-\d.\[\]]+)\)$', caseSensitive: false)
        .firstMatch(expression);
    if (simpleExpression != null) {
      return evalVariable(simpleExpression.group(1)!, dataMap);
    }

    // if we have multiple expressions, or mixing with text, return as String
    // greedy match anything inside a $() with letters, digits, period, square brackets.
    return expression.replaceAllMapped(RegExp(r'\$\(([a-z_-\d.\[\]]+)\)', caseSensitive: false),
            (match) => evalVariable("${match[1]}", dataMap).toString());

  }
  


  /// evaluate a variable's data from the given dataMap
  /// e.g data.result.output
  static dynamic evalVariable(String variable, Map<String, dynamic>? dataMap) {
    if (dataMap == null) {
      return variable;
    }
    List<String> tokens = variable.split('.');
    return _parseToken(tokens, 0, dataMap) ?? variable;
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