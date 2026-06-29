import 'package:ensemble_test_runner/ensemble_test_runner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses group with nested steps', () {
    const yaml = '''
id: grouped
startScreen: Home
steps:
  - group:
      name: validation
      steps:
        - expectVisible:
            id: submit
''';

    final test = EnsembleTestParser.parseString(yaml);
    expect(test.steps.length, 1);
    expect(test.steps.first.type, 'group');
    expect(test.steps.first.nestedSteps.length, 1);
    expect(test.steps.first.nestedSteps.first.type, 'expectVisible');
  });

  test('parses ifVisible with nested steps', () {
    const yaml = '''
id: conditional
startScreen: Home
steps:
  - ifVisible:
      id: banner
      steps:
        - tap:
            id: dismiss
''';

    final step = EnsembleTestParser.parseString(yaml).steps.first;
    expect(step.type, 'ifVisible');
    expect(step.args['id'], 'banner');
    expect(step.nestedSteps.single.type, 'tap');
  });
}
