import 'package:ensemble_test_runner/discovery/ensemble_test_execution_planner.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/parser/ensemble_test_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnsembleTestExecutionPlanner', () {
    test('orders prerequisite chain before independent startScreen tests', () {
      final byId = {
        'chain_root': _def('a/chain_root.test.yaml', '''
id: chain_root
startScreen: Home
steps:
  - expectVisible:
      id: x
'''),
        'chain_child': _def('b/chain_child.test.yaml', '''
id: chain_child
prerequisite: chain_root
steps:
  - expectVisible:
      id: y
'''),
        'standalone': _def('z/standalone.test.yaml', '''
id: standalone
startScreen: Other
steps:
  - expectVisible:
      id: z
'''),
      };

      final order = EnsembleTestExecutionPlanner.orderIdsForTest(byId);
      expect(order.indexOf('chain_root'), lessThan(order.indexOf('chain_child')));
      expect(order.indexOf('chain_child'), lessThan(order.indexOf('standalone')));
    });

    test('detects circular prerequisites', () {
      final byId = {
        'a': _def('a.test.yaml', '''
id: a
prerequisite: b
steps:
  - expectVisible:
      id: x
'''),
        'b': _def('b.test.yaml', '''
id: b
prerequisite: a
steps:
  - expectVisible:
      id: y
'''),
      };

      expect(
        () => EnsembleTestExecutionPlanner.orderIdsForTest(byId),
        throwsA(isA<EnsembleTestFailure>()),
      );
    });
  });
}

EnsembleTestDefinition _def(String assetPath, String yaml) {
  return EnsembleTestDefinition(
    assetPath: assetPath,
    testCase: EnsembleTestParser.parseString(yaml),
  );
}
