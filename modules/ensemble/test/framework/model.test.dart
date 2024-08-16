import 'package:ensemble/framework/model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test IntegerOrPercentage', ()
  {
    // Test case 1: Valid integer
    var intResult = IntegerOrPercentage.from(42);
    assert(intResult != null);
    assert(intResult!.integer == 42);
    assert(intResult!.percent == null);
    assert(intResult!.isPercentage() == false);
    assert(intResult!.getFixedValue() == 42.0);
    assert(intResult!.getFractionalValue() == null);

    // Test case 2: Valid percentage string
    var percentResult = IntegerOrPercentage.from("75%");
    assert(percentResult != null);
    assert(percentResult!.percent == 75);
    assert(percentResult!.integer == null);
    assert(percentResult!.isPercentage() == true);
    assert(percentResult!.getFixedValue() == null);
    assert(percentResult!.getFractionalValue() == 0.75);

    // Test case 3: Invalid percentage string
    var invalidPercentResult = IntegerOrPercentage.from("150%");
    assert(invalidPercentResult == null);

    // Test case 4: Valid integer string
    var intStringResult = IntegerOrPercentage.from("42");
    assert(intStringResult != null);
    assert(intStringResult!.integer == 42);
    assert(intStringResult!.percent == null);

    // Test case 5: Invalid string format
    var invalidStringResult = IntegerOrPercentage.from("abc");
    assert(invalidStringResult == null);

    // Test case 6: Valid double input
    var doubleResult = IntegerOrPercentage.from(42.7);
    assert(doubleResult != null);
    assert(doubleResult!.integer == 42);
    assert(doubleResult!.percent == null);

    // Test case 7: Valid percentage string with extra spaces
    var spacedPercentResult = IntegerOrPercentage.from("  85%  ");
    assert(spacedPercentResult != null);
    assert(spacedPercentResult!.percent == 85);
    assert(spacedPercentResult!.integer == null);

    // Test case 8: Edge case percentage 0%
    var zeroPercentResult = IntegerOrPercentage.from("0%");
    assert(zeroPercentResult != null);
    assert(zeroPercentResult!.percent == 0);
    assert(zeroPercentResult!.integer == null);
    assert(zeroPercentResult!.getFractionalValue() == 0.0);

    // Test case 9: Edge case percentage 100%
    var hundredPercentResult = IntegerOrPercentage.from("100%");
    assert(hundredPercentResult != null);
    assert(hundredPercentResult!.percent == 100);
    assert(hundredPercentResult!.integer == null);
    assert(hundredPercentResult!.isPercentage() == false);
    assert(hundredPercentResult!.getFixedValue() == double.infinity);
    assert(hundredPercentResult!.getFractionalValue() == null);

    // Test case 10: Null input
    var nullResult = IntegerOrPercentage.from(null);
    assert(nullResult == null);
  });
}
