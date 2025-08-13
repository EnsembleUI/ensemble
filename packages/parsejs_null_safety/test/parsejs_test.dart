import 'package:test/test.dart';
import 'package:parsejs_null_safety/parsejs_null_safety.dart';

void main() {
  group('ParseJS Basic Functionality', () {
    test('should parse simple JavaScript code', () {
      const code = 'var x = 42;';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.filename, isNull);
      expect(ast.body, isNotEmpty);
      expect(ast.body.length, equals(1));
    });

    test('should parse JavaScript with filename', () {
      const code = 'console.log("Hello World");';
      const filename = 'test.js';
      final ast = parsejs(code, filename: filename);

      expect(ast.filename, equals(filename));
      expect(ast.body, isNotEmpty);
    });

    test('should parse JavaScript expression', () {
      const code = 'x + y';
      final ast = parsejs(code, parseAsExpression: true);

      expect(ast, isNotNull);
      expect(ast.body, isNotEmpty);
    });

    test('should parse function declaration', () {
      const code = '''
        function add(a, b) {
          return a + b;
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body, isNotEmpty);
      expect(ast.body.length, equals(1));
    });

    test('should handle single statement', () {
      const code = 'var x = 1;';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should handle multiple statements', () {
      const code = 'var x = 1; var y = 2; var z = 3;';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(3));
    });
  });

  group('ParseJS Parsing Options', () {
    test('should handle firstLine parameter', () {
      const code = 'var x = 1;';
      final ast = parsejs(code, firstLine: 10);

      expect(ast, isNotNull);
      // Note: firstLine affects internal parsing but may not be directly accessible
    });

    test('should handle handleNoise parameter', () {
      const code = '#!/usr/bin/env node\nvar x = 1;';
      final ast = parsejs(code, handleNoise: true);

      expect(ast, isNotNull);
      expect(ast.body, isNotEmpty);
    });

    test('should handle annotations parameter', () {
      const code = 'var x = 1; var y = 2;';
      final ast = parsejs(code, annotations: true);

      expect(ast, isNotNull);
      expect(ast.body, isNotEmpty);
    });

    test('should handle parseAsExpression parameter', () {
      const code = 'a + b * c';
      final ast = parsejs(code, parseAsExpression: true);

      expect(ast, isNotNull);
      expect(ast.body, isNotEmpty);
    });
  });

  group('JavaScript Syntax Support', () {
    test('should parse variable declarations', () {
      const code = '''
        var x = 1;
        var y = 2;
        var z = 3;
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(3));
    });

    test('should parse function expressions', () {
      const code = '''
        var add = function(a, b) {
          return a + b;
        };
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse function declarations', () {
      const code = '''
        function multiply(a, b) {
          return a * b;
        }
        
        function divide(a, b) {
          return a / b;
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(2));
    });

    test('should parse object literals', () {
      const code = '''
        var obj = {
          name: 'John',
          age: 30,
          greet: function() {
            return 'Hello!';
          }
        };
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse array literals', () {
      const code = '''
        var arr = [1, 2, 3, 'hello', true];
        var matrix = [[1, 2], [3, 4]];
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(2));
    });

    test('should parse conditional statements', () {
      const code = '''
        if (x > 0) {
          console.log('Positive');
        } else if (x < 0) {
          console.log('Negative');
        } else {
          console.log('Zero');
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse conditional statements', () {
      const code = '''
        if (x > 0) {
          console.log('Positive');
        } else if (x < 0) {
          console.log('Negative');
        } else {
          console.log('Zero');
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse loops', () {
      const code = '''
        for (var i = 0; i < 10; i++) {
          console.log(i);
        }
        
        while (condition) {
          doSomething();
        }
        
        do {
          action();
        } while (condition);
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(3));
    });

    test('should parse try-catch blocks', () {
      const code = '''
        try {
          riskyOperation();
        } catch (error) {
          console.error(error);
        } finally {
          cleanup();
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse switch statements', () {
      const code = '''
        switch (value) {
          case 1:
            console.log('One');
            break;
          case 2:
            console.log('Two');
            break;
          default:
            console.log('Other');
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });
  });

  group('JavaScript Expressions', () {
    test('should parse arithmetic expressions', () {
      const code = 'var result = (a + b) * c / d % e;';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse logical expressions', () {
      const code = 'var flag = a && b || c && !d;';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse comparison expressions', () {
      const code = 'var valid = x > 0 && y <= 100 && z != null;';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse assignment expressions', () {
      const code = '''
        var x = 1;
        x += 2;
        x -= 3;
        x *= 4;
        x /= 5;
        x %= 6;
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(6));
    });

    test('should parse ternary operators', () {
      const code = 'var result = condition ? value1 : value2;';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse function calls', () {
      const code = '''
        func();
        func(arg1, arg2);
        obj.method();
        obj.method(arg1, arg2);
        func().method().property;
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(5));
    });
  });

  group('Error Handling', () {
    test('should handle invalid JavaScript syntax gracefully', () {
      expect(() {
        parsejs('var x = ;');
      }, throwsA(isA<ParseError>()));
    });

    test('should handle incomplete statements', () {
      expect(() {
        parsejs('var x =');
      }, throwsA(isA<ParseError>()));
    });

    test('should handle mismatched brackets', () {
      expect(() {
        parsejs('function test() { return 1;');
      }, throwsA(isA<ParseError>()));
    });

    test('should handle invalid expressions', () {
      expect(() {
        parsejs('var x = ;');
      }, throwsA(isA<ParseError>()));
    });
  });

  group('Edge Cases', () {
    test('should handle very long code', () {
      final longCode = 'var x = 1;\n' * 1000;
      final ast = parsejs(longCode);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1000));
    });

    test('should handle special characters in strings', () {
      const code = '''
        var str1 = "Hello 'World'";
        var str2 = 'Hello "World"';
        var str3 = "Line 1\\nLine 2\\tTab";
        var str4 = "Unicode: \\u0041\\u0042\\u0043";
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(4));
    });

    test('should handle regular expressions', () {
      const code = '''
        var regex1 = /pattern/;
        var regex2 = /pattern/gim;
        var regex3 = new RegExp("pattern", "gi");
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(3));
    });

    test('should handle complex nested structures', () {
      const code = '''
        var data = {
          users: [
            {
              name: 'John',
              age: 30,
              hobbies: ['reading', 'swimming']
            },
            {
              name: 'Jane',
              age: 25,
              hobbies: ['painting', 'dancing']
            }
          ],
          metadata: {
            total: 2,
            timestamp: new Date()
          }
        };
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });
  });

  group('Integration Tests', () {
    test('should parse utility function', () {
      const code = '''
        function debounce(func, wait) {
          var timeout;
          return function executedFunction() {
            var args = arguments;
            var later = function() {
              clearTimeout(timeout);
              func.apply(this, args);
            };
            clearTimeout(timeout);
            timeout = setTimeout(later, wait);
          };
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1));
    });

    test('should parse module-like structure', () {
      const code = '''
        (function() {
          'use strict';
          
          var privateVar = 'private';
          
          function privateFunction() {
            return privateVar;
          }
          
          window.publicAPI = {
            getValue: privateFunction,
            setValue: function(value) {
              privateVar = value;
            }
          };
        })();
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(1)); // IIFE
    });

    test('should parse event handling code', () {
      const code = '''
        function handleClick(event) {
          event.preventDefault();
          
          var target = event.target;
          var value = target.value;
          
          if (value && value.length > 0) {
            processInput(value);
          } else {
            showError('Please enter a value');
          }
        }
        
        function processInput(input) {
          try {
            var result = JSON.parse(input);
            displayResult(result);
          } catch (error) {
            console.error('Invalid JSON:', error);
            showError('Invalid input format');
          }
        }
      ''';
      final ast = parsejs(code);

      expect(ast, isNotNull);
      expect(ast.body.length, equals(2)); // Two functions
    });
  });
}
