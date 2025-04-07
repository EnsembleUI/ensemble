import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/context.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:jsparser/jsparser.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';

/// A validator that uses the visitor pattern to validate JavaScript code
class JSValidator extends RecursiveVisitor<bool> {
  final String code;
  final Program program;
  final Context context;
  late final JSInterpreter _interpreter;

  JSValidator(this.code, this.program, this.context) {
    _interpreter = JSInterpreter(code, program, context);
  }

  /// Validates the JavaScript AST with context-aware rules
  /// Checks for syntax errors, undefined variables/objects, invalid property or method access,
  /// and provides typo suggestions. Throws [JSException] if validation fails; returns true if valid.
  bool validate({Node? node}) {
    try {
      if (node != null) {
        return visit(node) ?? true;
      }

      // First pass: collect all function declarations and variable declarations
      for (var stmt in program.body) {
        if (stmt is FunctionDeclaration) {
          if (stmt.function.name != null) {
            _interpreter.addToContext(stmt.function.name!, true);
          }
          // Create a new context for the function
          Context functionContext = SimpleContext({});
          // Add function parameters to the context
          if (stmt.function.params != null) {
            for (var param in stmt.function.params) {
              if (param is Name) {
                functionContext.addDataContextById(param.value, true);
              }
            }
          }
        } else if (stmt is VariableDeclaration) {
          for (var declarator in stmt.declarations) {
            _interpreter.addToContext(declarator.name, true);
          }
        }
      }

      // Second pass: validate everything
      for (var stmt in program.body) {
        visit(stmt);
      }
      return true;
    } catch (e) {
      if (e is JSException) throw e;
      throw JSException(1, e.toString(),
          detailedError: 'Code: $code', originalError: e);
    }
  }

  /// Checks whether the given [name] exists in the [programContext]. If not,
  /// throws an exception with details and possible recovery suggestions.
  void validateContextExistence(String name, Node node, Context programContext,
      {bool isObject = false}) {
    if (!programContext.hasContext(name)) {
      final available = programContext.getContextMap().keys.join(", ");
      throw JSException(
        node.line ?? 1,
        '${isObject ? "Object" : "Variable"} "$name" is not defined in the current context',
        detailedError:
            'Code: ${_interpreter.getCode(node)}\nAvailable ${isObject ? "objects" : "variables"}: $available',
        recovery:
            'Check if you have declared the ${isObject ? "object" : "variable"} correctly (including case sensitivity).',
      );
    }
  }

  /// Validates that a property or method exists on the given object. In case
  /// of a typo, it provides suggestions based on Levenshtein distance.
  void validatePropertyOrMethodAccess(
      String propertyName, String objectName, dynamic obj, Node node) {
    if (obj == null) {
      throw JSException(
        node.line ?? 1,
        'Cannot access property "$propertyName" on null or undefined object "$objectName"',
        detailedError: 'Code: ${_interpreter.getCode(node)}',
        recovery:
            'Make sure the object is properly initialized before accessing its properties.',
      );
    }

    if (obj is Invokable) {
      final hasProp = obj.hasGettableProperty(propertyName);
      final hasMethod = obj.hasMethod(propertyName);
      if (!hasProp && !hasMethod) {
        final availableProps = Invokable.getGettableProperties(obj);
        final availableMethods = obj.methods().keys.toList();
        final suggestions = [
          ...availableProps
              .where((prop) => _levenshteinDistance(propertyName, prop) <= 2),
          ...availableMethods.where(
              (method) => _levenshteinDistance(propertyName, method) <= 2)
        ];
        var recovery =
            'Check if you have used the correct property name (case sensitive).';
        if (suggestions.isNotEmpty) {
          recovery += '\nDid you mean one of these? ${suggestions.join(", ")}';
        }
        throw JSException(
          node.line ?? 1,
          'Property "$propertyName" does not exist on object "$objectName"',
          detailedError:
              'Code: ${_interpreter.getCode(node)}\nAvailable properties: ${availableProps.join(", ")}\nAvailable methods: ${availableMethods.join(", ")}',
          recovery: recovery,
        );
      }
    } else if (obj is Map) {
      if (!obj.containsKey(propertyName)) {
        final availableProps = obj.keys.toList();
        final suggestions = availableProps
            .where((prop) =>
                _levenshteinDistance(propertyName, prop.toString()) <= 2)
            .toList();
        var recovery =
            'Check if you have used the correct property name (case sensitive).';
        if (suggestions.isNotEmpty) {
          recovery += '\nDid you mean one of these? ${suggestions.join(", ")}';
        }
        throw JSException(
          node.line ?? 1,
          'Property "$propertyName" does not exist on object "$objectName"',
          detailedError:
              'Code: ${_interpreter.getCode(node)}\nAvailable properties: ${availableProps.join(", ")}',
          recovery: recovery,
        );
      }
    }
  }

  /// A helper method to calculate the Levenshtein distance between two strings.
  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> prev = List<int>.generate(s2.length + 1, (i) => i);
    List<int> curr = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = [curr[j] + 1, prev[j + 1] + 1, prev[j] + cost]
            .reduce((a, b) => a < b ? a : b);
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }
    return prev[s2.length];
  }

  @override
  bool visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.function.name != null) {
      _interpreter.addToContext(node.function.name!, true);
    }
    visit(node.function.body);
    return true;
  }

  @override
  bool visitFunctionExpression(FunctionExpression node) {
    visit(node.function.body);
    return true;
  }

  @override
  bool visitArrowFunctionNode(ArrowFunctionNode node) {
    visit(node.body);
    return true;
  }

  @override
  bool visitVariableDeclaration(VariableDeclaration node) {
    for (var declarator in node.declarations) {
      _interpreter.addToContext(declarator.name, true);
      if (declarator.init != null) {
        visit(declarator.init!);
      }
    }
    return true;
  }

  @override
  bool visitCall(CallExpression node) {
    try {
      visit(node.callee);
      if (node.callee is MemberExpression) {
        final member = node.callee as MemberExpression;
        if (member.object is NameExpression) {
          String objectName = (member.object as NameExpression).name.value;
          validateContextExistence(objectName, node, context, isObject: true);
          dynamic obj = context.getContextById(objectName);
          if (obj != null && member.property is Name) {
            String methodName = (member.property as Name).value;
            validatePropertyOrMethodAccess(methodName, objectName, obj, node);
          }
        }
      } else if (node.callee is NameExpression) {
        String name = (node.callee as NameExpression).name.value;
        validateContextExistence(name, node, context);
      }
      for (var arg in node.arguments) {
        visit(arg);
      }
    } catch (e) {
      if (e is! JSException) {
        print('Validation warning: ${e.toString()}');
      } else {
        rethrow;
      }
    }
    return true;
  }

  @override
  bool visitMember(MemberExpression node) {
    try {
      visit(node.object);
      visit(node.property);

      if (node.object is NameExpression) {
        String objectName = (node.object as NameExpression).name.value;
        validateContextExistence(objectName, node, context, isObject: true);
        dynamic obj = context.getContextById(objectName);
        if (obj != null && node.property is Name) {
          validatePropertyOrMethodAccess(
              (node.property as Name).value, objectName, obj, node);
        }
      } else if (node.object is MemberExpression) {
        dynamic obj = _interpreter.getValueFromNode(node.object);
        if (obj != null && node.property is Name) {
          validatePropertyOrMethodAccess(
              (node.property as Name).value, 'object', obj, node);
        }
      }
    } catch (e) {
      if (e is! JSException) {
        print('Validation warning: ${e.toString()}');
      } else {
        rethrow;
      }
    }
    return true;
  }

  @override
  bool visitNameExpression(NameExpression node) {
    try {
      String name = node.name.value;
      validateContextExistence(name, node, context);
    } catch (e) {
      if (e is! JSException) {
        print('Validation warning: ${e.toString()}');
      } else {
        rethrow;
      }
    }
    return true;
  }

  @override
  bool visitAssignment(AssignmentExpression node) {
    try {
      if (node.left is NameExpression) {
        String name = (node.left as NameExpression).name.value;
        validateContextExistence(name, node, context);
      } else if (node.left is MemberExpression) {
        visit(node.left);
      }
      visit(node.right);
    } catch (e) {
      if (e is! JSException) {
        print('Validation warning: ${e.toString()}');
      } else {
        rethrow;
      }
    }
    return true;
  }

  @override
  bool visitObject(ObjectExpression node) {
    for (var prop in node.properties) {
      visit(prop.value);
    }
    return true;
  }

  @override
  bool defaultNode(Node node) {
    node.forEach((child) => visit(child));
    return true;
  }
}
