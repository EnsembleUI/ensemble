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

}