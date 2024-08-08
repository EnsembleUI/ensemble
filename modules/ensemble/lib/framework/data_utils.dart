import 'package:ensemble/framework/scope.dart';

class DataUtils{

  static final onlyExpression =
  RegExp(r'''^\$\{([^}]+)\}$''', caseSensitive: false);

  static final containExpression =
  RegExp(r'''\$\{([^}{]+(?:\{[^}{]*\}[^}{]*)*)\}''', caseSensitive: false);

  // match an expression and AST e.g //@code <expression>\n<AST> in group1 and group2
  static final expressionAndAst =
      RegExp(r'^//@code\s+([^\n]+)\s*', caseSensitive: false);

  /// parse an Expression and AST into a DataExpression object.
  /// There are two variations:
  /// 1. <expression>
  /// 2. //@code <expression>\n<AST>
  static DataExpression? parseDataExpression(dynamic input) {
    if (input is String) {
      return _parseDataExpressionFromString(input);
    } else if (input is List) {
      List<String> tokens = [];
      for (final inputEntry in input) {
        tokens.addAll(parseDataExpression(inputEntry)?.expressions ?? []);
      }
      if (tokens.isNotEmpty) {
        return DataExpression(rawExpression: input, expressions: tokens);
      }
    } else if (input is Map) {
      List<String> tokens = [];
      input.forEach((_, value) {
        // we probably should recursively go inside the Map, but we have a problem
        // where a property can be a passthrough and only meant to be evaluated
        // at the time of use, or be evaluated inside a widget
        // e.g. a widget that takes in a widget with itemTemplate e.g. LoadingContainer
        // LoadingContainer takes in a widget which potentially has itemTemplate.
        // If we recursively go through this, we would inadvertently evaluate the itemTemplate
        // Technically we can use passthroughSetters() but that's error prone
        // TODO: find a more seamless way before run the recursion below.
        // tokens.addAll(parseDataExpression(value)?.expressions ?? []);

        // only evaluate string for now
        if (value is String) {
          DataExpression? dataEntry = _parseDataExpressionFromString(value);
          tokens.addAll(dataEntry?.expressions ?? []);
        }
      });
      if (tokens.isNotEmpty) {
        return DataExpression(rawExpression: input, expressions: tokens);
      }
    }
    return null;
  }

  /// get the list of expression from the raw string
  /// [input]: Hello $(firstname) $(lastname)
  /// @return [ $(firstname), $(lastname) ]
  static List<String> getExpressionTokens(String input) {
    return containExpression.allMatches(input).map((e) => e.group(0)!).toList();
  }

  static DataExpression? _parseDataExpressionFromString(String input) {
    // first match //@code <expression>\n<AST> as it is what we have
    RegExpMatch? match = expressionAndAst.firstMatch(input);
    if (match != null) {
      return DataExpression(
          rawExpression: match.group(1)!,
          expressions: getExpressionTokens(match.group(1)!));
    }
    // fallback to match <expression> only. This is if we don't turn on AST
    List<String> tokens = getExpressionTokens(input);
    if (tokens.isNotEmpty) {
      return DataExpression(rawExpression: input, expressions: tokens);
    }
    return null;
  }

  /// is it $(....)
  static bool isExpression(String expression) {
    return onlyExpression.hasMatch(expression);
  }

  /// contains one or more expression e.g Hello $(firstname) $(lastname)
  static bool hasExpression(String expression) {
    return containExpression.hasMatch(expression);
  }
}
