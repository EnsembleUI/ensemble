import 'dart:convert';

import 'package:ensemble/framework/data_utils.dart';
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
    expect(DataUtils.isExpression(r'${hi}'), true);
    expect(DataUtils.isExpression(r'hello ${hi}'), false);
    expect(DataUtils.isExpression(r'hi'), false);

    expect(DataUtils.hasExpression(r'${hi}'), true);
    expect(DataUtils.hasExpression(r'Hi ${name}'), true);
    expect(DataUtils.hasExpression(r'${hi} there'), true);
    expect(DataUtils.hasExpression(r'hi'), false);

    expect(DataUtils.getExpressionTokens(r''), []);
    expect(DataUtils.getExpressionTokens(r'hello world'), []);
    expect(DataUtils.getExpressionTokens(r'${hi}'), [r'${hi}']);
    expect(DataUtils.getExpressionTokens(r'hi ${name}'), [r'${name}']);
    expect(DataUtils.getExpressionTokens(r'${first} ${last}'),
        [r'${first}', r'${last}']);
    expect(DataUtils.getExpressionTokens(r'hi ${48 * 2 * 122} ${last}'),
        [r'${48 * 2 * 122}', r'${last}']);
    expect(
        DataUtils.getExpressionTokens(
            r'hey there ${Math.floor(device.width / 2) - ((48 * 2 + 12)/2)} hello'),
        [r'${Math.floor(device.width / 2) - ((48 * 2 + 12)/2)}']);
  });

  test("ISO date only", () {
    expect(DateTime.parse('2022-05-24T12:00:00').toIso8601DateString(),
        '2022-05-24');
  });

  test("get expression tokens", () {
    expect(DataUtils.getExpressionTokens(''), []);
    expect(DataUtils.getExpressionTokens('hi'), []);
    expect(DataUtils.getExpressionTokens('hi \${name}'), ['\${name}']);
    expect(DataUtils.getExpressionTokens('\${name}'), ['\${name}']);
    expect(DataUtils.getExpressionTokens('hi \${person.first} \${person.last}'),
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
    RegExpMatch? match = DataUtils.expressionAndAst.firstMatch('//@code $expr');
    expect(match?.group(1), expr);
  });

  test("parse into a DataExpression", () {
    String expr = 'Name is \${person.first} \${person.last}';
    DataExpression? dataExpression = DataUtils.parseDataExpression('//@code $expr');
    expect(dataExpression?.rawExpression, expr);
    expect(
        dataExpression?.expressions, ['\${person.first}', '\${person.last}']);

    // this time just expression only.
    dataExpression = DataUtils.parseDataExpression(expr);
    expect(dataExpression?.rawExpression, expr);
    expect(
        dataExpression?.expressions, ['\${person.first}', '\${person.last}']);
  });

  test('parse short-hand ifelse', () {
    String expr =
        '\${ getWifiStatus.body.data.Status ? 0xFF009900 : 0xFFE52E2E }';
    DataExpression? dataExpression = DataUtils.parseDataExpression('//@code $expr');
    expect(dataExpression?.rawExpression, expr);
    expect(dataExpression?.expressions, [expr]);
  });

  test("another short-hand", () {
    String expr =
        "\${getPrivWiFi.body.status.wlanvap.vap5g0priv.VAPStatus == 'Up' ? true : false }";
    DataExpression? dataExpression = DataUtils.parseDataExpression('//@code $expr');
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

  group('DataGrid sort - list of nested map objects', () {
    List<dynamic> hotels = [];

    setUp(() {
      const json = r"""
      {
        "hotels": [
            {
                "name": "Grand Royal Hotel",
                "location": "San Francisco",
                "price": 200,
                "other": {
                    "restaurantId": 2,
                    "type": "Fine Dining",
                    "maxPrice": 230
                }
            },
            {
                "name": "Queen Hotel",
                "location": "East Side, San Francisco",
                "price": 300,
                "other": {
                    "restaurantId": 1,
                    "type": "Cafe",
                    "maxPrice": 470
                }
            },
            {
                "name": "Alif",
                "location": "Wembley, London",
                "price": 100,
                "other": {
                    "restaurantId": 6,
                    "type": "Food Truck",
                    "maxPrice": 160
                }
            },
            {
                "name": "Bariz Restaurant",
                "location": "Canada",
                "price": 400,
                "other": {
                    "restaurantId": 8,
                    "type": "Buffet Style",
                    "maxPrice": 560
                }
            },
            {
                "name": "KFC",
                "location": "Los Vegas",
                "price": 700,
                "other": {
                    "restaurantId": 3,
                    "type": "Fast Food",
                    "maxPrice": 800
                }
            }
        ]
    }
    """;

      final data = jsonDecode(json);
      hotels = data['hotels'] as List<dynamic>;
    });

    // Before Sorting
    test('Before Sorting', () {
      expect(hotels.first['name'], 'Grand Royal Hotel');
      expect(hotels.last['name'], 'KFC');
    });

    // Sorting - Ascending Order
    test('After Sorting - Ascending Order (key - restaurantId)', () {
      final hotelsSortWithRestaurantKey = Utils.sortMapObjectsByKey(
          hotels, 'restaurantId',
          isAscendingOrder: true);
      expect(hotelsSortWithRestaurantKey.first['name'], 'Queen Hotel');
      expect(hotelsSortWithRestaurantKey.last['name'], 'Bariz Restaurant');
    });

    test('After Sorting - Ascending Order (key - location)', () {
      final hotelsSortWithRestaurantKey =
          Utils.sortMapObjectsByKey(hotels, 'location', isAscendingOrder: true);
      expect(hotelsSortWithRestaurantKey.first['location'], 'Canada');
      expect(hotelsSortWithRestaurantKey.last['location'], 'Wembley, London');
    });

    test('After Sorting - Ascending Order (key - maxPrice)', () {
      final hotelsSortWithRestaurantKey =
          Utils.sortMapObjectsByKey(hotels, 'maxPrice', isAscendingOrder: true);
      expect(hotelsSortWithRestaurantKey.first['price'], 100);
      expect(hotelsSortWithRestaurantKey.last['price'], 700);
    });

    // Sorting - Descending Order
    test('After Sorting - Descending Order (key - restaurantId)', () {
      final hotelsSortWithRestaurantKey = Utils.sortMapObjectsByKey(
          hotels, 'restaurantId',
          isAscendingOrder: false);
      expect(hotelsSortWithRestaurantKey.first['name'], 'Bariz Restaurant');
      expect(hotelsSortWithRestaurantKey.last['name'], 'Queen Hotel');
    });

    test('After Sorting - Descending Order (key - location)', () {
      final hotelsSortWithRestaurantKey = Utils.sortMapObjectsByKey(
          hotels, 'location',
          isAscendingOrder: false);
      expect(hotelsSortWithRestaurantKey.first['location'], 'Wembley, London');
      expect(hotelsSortWithRestaurantKey.last['location'], 'Canada');
    });

    test('After Sorting - Descending Order (key - maxPrice)', () {
      final hotelsSortWithRestaurantKey = Utils.sortMapObjectsByKey(
          hotels, 'maxPrice',
          isAscendingOrder: false);
      expect(hotelsSortWithRestaurantKey.first['price'], 700);
      expect(hotelsSortWithRestaurantKey.last['price'], 100);
    });
  });

  group('getColor Tests', () {
    const myColor = Color(0xff123456);

    test('color hex with #', () {
      expect(Utils.getColor('#123456'), equals(myColor));
    });

    test('color hex without #', () {
      expect(Utils.getColor('123456'), equals(myColor));
    });

    test('hex with alpha and #', () {
      expect(Utils.getColor('#123456ff'), equals(myColor));
    });

    test('hex with alpha', () {
      expect(Utils.getColor('123456ff'), equals(myColor));
    });

    test('returns null for invalid hex string', () {
      expect(Utils.getColor('12345g'), isNull);
    });

    test('returns Color for valid integer color value', () {
      expect(Utils.getColor(0xff123456), equals(const Color(0xff123456)));
    });

    test('test color as a string', () {
      expect(Utils.getColor("0xff123456"), equals(const Color(0xff123456)));
    });

    test('returns correct Color for named color strings', () {
      expect(Utils.getColor('red'), equals(Colors.red));
      expect(Utils.getColor('blue'), equals(Colors.blue));
    });

    test('returns Colors.transparent for transparent string', () {
      expect(Utils.getColor('transparent'), equals(Colors.transparent));
    });

    test('returns null for non-string, non-int types', () {
      expect(Utils.getColor([255, 0, 0]), isNull);
    });

    test('returns null for undefined named colors', () {
      expect(Utils.getColor('not a color'), isNull);
    });

    test('returns correct Color for transparent keyword variations', () {
      expect(Utils.getColor('.transparent'), equals(Colors.transparent));
    });

    // Additional tests for each named color
    test('returns correct Color for each named color string', () {
      expect(Utils.getColor('black'), equals(Colors.black));
      expect(Utils.getColor('white'), equals(Colors.white));
      // Continue testing all other named colors...
    });
  });
}

void assertIconEquality(IconModel first, IconModel second) {
  expect(first.icon, second.icon);
  expect(first.library, second.library);
  expect(first.size, second.size);
  expect(first.color, second.color);
}
