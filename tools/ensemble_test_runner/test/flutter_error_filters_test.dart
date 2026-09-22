import 'package:ensemble_test_runner/runner/flutter_error_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deactivated-ancestor JS races are non-fatal', () {
    expect(
      isNonFatalFlutterDiagnostic(
        "Javascript error when running code block - … "
        "Looking up a deactivated widget's ancestor is unsafe.",
      ),
      isTrue,
    );
  });

  test('real framework errors remain fatal', () {
    expect(
      isNonFatalFlutterDiagnostic(
        'Null check operator used on a null value',
      ),
      isFalse,
    );
  });
}
