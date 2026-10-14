import 'package:ensemble_test_runner/cli/cli_test_selection.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  group('CliTestSelection', () {
    test('matches ids, profiles, tags, and devices on expanded definitions',
        () {
      const definition = ExpandedShardDefinition(
        id: 'checkout[happy][phone]',
        assetPath: 'tests/checkout.test.yaml',
        feature: 'checkout',
        tags: ['smoke', 'payments'],
        profile: 'happy',
        deviceId: 'phone',
        session: null,
      );

      expect(
        CliTestSelection.matchesExpandedShardSelection(
          definition,
          const [
            '--id=checkout',
            '--profile=happy',
            '--tag=smoke',
            '--device=phone',
          ],
        ),
        isTrue,
      );
      expect(
        CliTestSelection.matchesExpandedShardSelection(
          definition,
          const ['--device=tablet'],
        ),
        isFalse,
      );
    });

    test('expands profile groups when matching a YAML document', () {
      final config = EnsembleTestConfig(
        profileGroups: const {
          'release': ['happy', 'loggedOut'],
        },
      );
      final doc = loadYaml('''
id: checkout
profiles: [release]
tags: [smoke]
''') as YamlMap;

      expect(
        CliTestSelection.matchesShardSelection(
          'tests/checkout.test.yaml',
          doc,
          const ['--profile=happy'],
          config: config,
        ),
        isTrue,
      );
      expect(
        CliTestSelection.profileNamesForShard(doc, config: config),
        ['happy', 'loggedOut'],
      );
    });

    test('selects a file path before parsing its document', () {
      expect(
        CliTestSelection.values(
          const ['--tag=smoke,release', '--tag=regression'],
          '--tag',
        ),
        ['smoke,release', 'regression'],
      );
      expect(
        CliTestSelection.valueSet(
          const ['--tag=smoke,release', '--tag=regression'],
          '--tag',
        ),
        {'smoke', 'release', 'regression'},
      );
      expect(
        CliTestSelection.hasSelection(const ['--device=phone']),
        isTrue,
      );
      expect(
        CliTestSelection.matchesShardSelection(
          'tests/payments.test.yaml',
          null,
          const ['--path=payments'],
        ),
        isTrue,
      );
      expect(
        CliTestSelection.hasShardSelection(const ['--tag=smoke']),
        isTrue,
      );
    });
  });
}
