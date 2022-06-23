import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  test('get double', () {
    dynamic value = 2.3;
    expect(Utils.getDouble(value, fallback: 0), value);

    value = 3;
    expect(Utils.getDouble(value, fallback: 0), 3.0);

    value = 0;
    expect(Utils.getDouble(value, fallback: 0), 0);

    value = '12.2';
    expect(Utils.getDouble(value, fallback: 0), 12.2);

    value = false;
    expect(Utils.getDouble(value, fallback: 0), 0);

    value = 'blah';
    expect(Utils.getDouble(value, fallback: 0), 0);

    value = null;
    expect(Utils.getDouble(value, fallback: 0), 0);

  });

  test('expressions utility', () {
    expect(Utils.isExpression(r'${hi}'), true);
    expect(Utils.isExpression(r'hello ${hi}'), false);
    expect(Utils.isExpression(r'hi'), false);

    expect(Utils.hasExpression(r'${hi}'), true);
    expect(Utils.hasExpression(r'Hi ${name}'), true);
    expect(Utils.hasExpression(r'${hi} there'), true);
    expect(Utils.hasExpression(r'hi'), false);

    expect(Utils.getExpressionTokens(r''), []);
    expect(Utils.getExpressionTokens(r'hello world'), []);
    expect(Utils.getExpressionTokens(r'${hi}'), [r'${hi}']);
    expect(Utils.getExpressionTokens(r'hi ${name}'), [r'${name}']);
    expect(Utils.getExpressionTokens(r'${first} ${last}'), [r'${first}', r'${last}']);
    expect(Utils.getExpressionTokens(r'hi ${first} ${last}'), [r'${first}', r'${last}']);
  });

  test("ISO date only", () {
    expect(DateTime.parse('2022-05-24T12:00:00').toIso8601DateString(), '2022-05-24');
  });

  test("get expression tokens", () {
    expect(Utils.getExpressionTokens(''), []);
    expect(Utils.getExpressionTokens('hi'), []);
    expect(Utils.getExpressionTokens('hi \${name}'), ['\${name}']);
    expect(Utils.getExpressionTokens('\${name}'), ['\${name}']);
    expect(Utils.getExpressionTokens('hi \${person.first} \${person.last}'), ['\${person.first}', '\${person.last}']);
  });

  test("get AST after the comment //@code", () {
    expect(Utils.codeAfterComment.firstMatch('//@code\n{"hello":"world"}')?.group(1), '{"hello":"world"}');
    expect(Utils.codeAfterComment.firstMatch('//@code\n\nblah\nblah')?.group(1), 'blah\nblah');
    expect(Utils.codeAfterComment.firstMatch('//@code \${myExpr.var}\n\ndata')?.group(1), 'data');
  });

  test("get both Expression and AST", () {
    String expr = '\${person.name}';
    String ast = '{"hello":"there"}';
    RegExpMatch? match = Utils.expressionAndAst.firstMatch('//@code $expr\n$ast');
    expect(match?.group(1), expr);
    expect(match?.group(2), ast);
  });

  test("parse into a DataExpression", () {
    String expr = 'Name is \${person.first} \${person.last}';
    String ast = '{"ast":"content"}';
    DataExpression? dataExpression = Utils.parseDataExpression('//@code $expr\n$ast');
    expect(dataExpression?.rawExpression, expr);
    expect(dataExpression?.expressions, ['\${person.first}', '\${person.last}']);
    expect(dataExpression?.astExpression, ast);

    // this time just expression only.
    dataExpression = Utils.parseDataExpression(expr);
    expect(dataExpression?.rawExpression, expr);
    expect(dataExpression?.expressions, ['\${person.first}', '\${person.last}']);
    expect(dataExpression?.astExpression, null);
  });

}