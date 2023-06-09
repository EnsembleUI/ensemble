import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
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

  test('strip ending arrays', () {
    expect(Utils.stripEndingArrays(''), '');
    expect(Utils.stripEndingArrays('hello'), 'hello');
    expect(Utils.stripEndingArrays('hello[0]'), 'hello');
    expect(Utils.stripEndingArrays('hello[name]'), 'hello');
    expect(Utils.stripEndingArrays('hello[0][12]'), 'hello');
    expect(Utils.stripEndingArrays('hello[one][two][three]'), 'hello');
    expect(Utils.stripEndingArrays('hello[0]there[1]'), 'hello[0]there');
    expect(Utils.stripEndingArrays('hello.there'), 'hello.there');
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
    expect(Utils.getExpressionTokens(r'${first} ${last}'),
        [r'${first}', r'${last}']);
    expect(Utils.getExpressionTokens(r'hi ${48 * 2 * 122} ${last}'),
        [r'${48 * 2 * 122}', r'${last}']);
    expect(
        Utils.getExpressionTokens(
            r'hey there ${Math.floor(device.width / 2) - ((48 * 2 + 12)/2)} hello'),
        [r'${Math.floor(device.width / 2) - ((48 * 2 + 12)/2)}']);
  });

  test("ISO date only", () {
    expect(DateTime.parse('2022-05-24T12:00:00').toIso8601DateString(),
        '2022-05-24');
  });

  test("get expression tokens", () {
    expect(Utils.getExpressionTokens(''), []);
    expect(Utils.getExpressionTokens('hi'), []);
    expect(Utils.getExpressionTokens('hi \${name}'), ['\${name}']);
    expect(Utils.getExpressionTokens('\${name}'), ['\${name}']);
    expect(Utils.getExpressionTokens('hi \${person.first} \${person.last}'),
        ['\${person.first}', '\${person.last}']);
  });

  test("get AST after the comment //@code", () {
    expect(
        Utils.codeAfterComment
            .firstMatch('//@code\n{"hello":"world"}')
            ?.group(1),
        '{"hello":"world"}');
    expect(Utils.codeAfterComment.firstMatch('//@code\n\nblah\nblah')?.group(1),
        'blah\nblah');
    expect(
        Utils.codeAfterComment
            .firstMatch('//@code \${myExpr.var}\n\ndata')
            ?.group(1),
        'data');
  });

  test("get both Expression and AST", () {
    String expr = '\${person.name}';
    RegExpMatch? match =
        Utils.expressionAndAst.firstMatch('//@code $expr');
    expect(match?.group(1), expr);
  });

  test("parse into a DataExpression", () {
    String expr = 'Name is \${person.first} \${person.last}';
    DataExpression? dataExpression =
        Utils.parseDataExpression('//@code $expr');
    expect(dataExpression?.rawExpression, expr);
    expect(
        dataExpression?.expressions, ['\${person.first}', '\${person.last}']);

    // this time just expression only.
    dataExpression = Utils.parseDataExpression(expr);
    expect(dataExpression?.rawExpression, expr);
    expect(
        dataExpression?.expressions, ['\${person.first}', '\${person.last}']);
  });

  test('parse short-hand ifelse', () {
    String expr =
        '\${ getWifiStatus.body.data.Status ? 0xFF009900 : 0xFFE52E2E }';
    DataExpression? dataExpression =
        Utils.parseDataExpression('//@code $expr');
    expect(dataExpression?.rawExpression, expr);
    expect(dataExpression?.expressions, [expr]);
  });

  test("another short-hand", () {
    String expr =
        "\${getPrivWiFi.body.status.wlanvap.vap5g0priv.VAPStatus == 'Up' ? true : false }";
    DataExpression? dataExpression =
        Utils.parseDataExpression('//@code $expr');
    expect(dataExpression?.rawExpression, expr);
    expect(dataExpression?.expressions, [expr]);
  });

  test("date time", () {
    TimeOfDay? timeOfDay = Utils.getTimeOfDay('8:30');
    expect(timeOfDay!.toIso8601TimeString(), '08:30:00');

    timeOfDay = Utils.getTimeOfDay('13:30');
    expect(timeOfDay!.toIso8601TimeString(), '13:30:00');
    expect(timeOfDay.compareTo(const TimeOfDay(hour: 13, minute: 40)), -1);
    expect(timeOfDay.compareTo(const TimeOfDay(hour: 14, minute: 2)), -1);
    expect(timeOfDay.compareTo(const TimeOfDay(hour: 13, minute: 30)), 0);
    expect(timeOfDay.compareTo(const TimeOfDay(hour: 12, minute: 40)), 1);
    expect(timeOfDay.compareTo(const TimeOfDay(hour: 1, minute: 1)), 1);
  });

  test("getIcon() short-hand", () {
    IconModel outputModel = Utils.getIcon('home')!;
    IconModel model = IconModel('home');
    assertIconEquality(outputModel, model);

    outputModel = Utils.getIcon('home fontAwesome')!;
    model = IconModel('home', library: 'fontAwesome');
    assertIconEquality(outputModel, model);
  });

  test("getIcon() key-value", () {
    WidgetsFlutterBinding.ensureInitialized();

    Map<String, dynamic> map = {'name': 'home', 'library': 'fontAwesome'};
    IconModel outputModel = Utils.getIcon(map)!;
    IconModel model = IconModel('home', library: 'fontAwesome');
    assertIconEquality(outputModel, model);

    map = {
      'name': 'home',
      'library': 'fontAwesome',
      'color': 'green',
      'size': 23
    };
    outputModel = Utils.getIcon(map)!;
    model = IconModel('home',
        library: 'fontAwesome', color: Colors.green, size: 23);
    assertIconEquality(outputModel, model);
  });

  test('stripping query params from assets', () {
    expect(Utils.stripQueryParamsFromAsset(''), '');
    expect(Utils.stripQueryParamsFromAsset(' '), ' ');
    expect(Utils.stripQueryParamsFromAsset('?'), '');
    expect(Utils.stripQueryParamsFromAsset(' ?'), ' ');
    expect(Utils.stripQueryParamsFromAsset('??'), '');
    expect(Utils.stripQueryParamsFromAsset('a?'), 'a');
    expect(Utils.stripQueryParamsFromAsset('a?b'), 'a');
    expect(Utils.stripQueryParamsFromAsset('my-image.png'), 'my-image.png');
    expect(Utils.stripQueryParamsFromAsset('image.jpg?x=abc'), 'image.jpg');
    expect(
        Utils.stripQueryParamsFromAsset(
            'https://hello.com/image_1.jpg?a=b&b=c'),
        'https://hello.com/image_1.jpg');
    expect(Utils.stripQueryParamsFromAsset('me.png?a=b?b=c&c=d'), 'me.png');
  });
}

void assertIconEquality(IconModel first, IconModel second) {
  expect(first.icon, second.icon);
  expect(first.library, second.library);
  expect(first.size, second.size);
  expect(first.color, second.color);
}
