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
    expect(Utils.isExpression(r'$(hi)'), true);
    expect(Utils.isExpression(r'hello $(hi)'), false);
    expect(Utils.isExpression(r'hi'), false);

    expect(Utils.hasExpression(r'$(hi)'), true);
    expect(Utils.hasExpression(r'Hi $(name)'), true);
    expect(Utils.hasExpression(r'$(hi) there'), true);
    expect(Utils.hasExpression(r'hi'), false);

    expect(Utils.getExpressionsFromString(r''), []);
    expect(Utils.getExpressionsFromString(r'hello world'), []);
    expect(Utils.getExpressionsFromString(r'$(hi)'), [r'$(hi)']);
    expect(Utils.getExpressionsFromString(r'hi $(name)'), [r'$(name)']);
    expect(Utils.getExpressionsFromString(r'$(first) $(last)'), [r'$(first)', r'$(last)']);
    expect(Utils.getExpressionsFromString(r'hi $(first) $(last)'), [r'$(first)', r'$(last)']);
  });


}