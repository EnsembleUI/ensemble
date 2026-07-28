import 'dart:io';

import 'package:ensemble_test_runner/cli/ensemble_test_cli.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('parallel sharding splits scenario and device runs by expanded id',
      () async {
    final root = Directory.systemTemp.createTempSync('ensemble_cli_shards_');
    addTearDown(() => root.deleteSync(recursive: true));

    final appDir = root.path;
    Directory(p.join(appDir, 'ensemble')).createSync(recursive: true);
    Directory(p.join(appDir, 'ensemble', 'apps', 'demo', 'tests'))
        .createSync(recursive: true);

    File(p.join(appDir, 'ensemble', 'ensemble-config.yaml')).writeAsStringSync(
      '''
definitions:
  local:
    path: ensemble/apps/demo
''',
    );
    File(p.join(appDir, 'ensemble', 'apps', 'demo', 'tests', 'config.yaml'))
        .writeAsStringSync(
      '''
devices:
  - id: iphone
    platform: ios
    model: iPhone 15 Pro
  - id: android
    platform: android
    model: Samsung Galaxy S20
''',
    );
    File(p.join(
      appDir,
      'ensemble',
      'apps',
      'demo',
      'tests',
      'scenario.test.yaml',
    )).writeAsStringSync(
      '''
id: scenario_flow
startScreen: Home
scenarios:
  - id: happy
    vars:
      title: Happy
  - id: empty
    vars:
      title: Empty
steps:
  - expectText:
      text: \${scenario.title}
''',
    );

    final shards = await planShardRunIdsForTest(
      appDir: appDir,
      jobs: 2,
    );
    final ids = shards.expand((shard) => shard).toList()..sort();

    expect(shards, hasLength(2));
    expect(shards.every((shard) => shard.isNotEmpty), isTrue);
    expect(
      ids,
      [
        'scenario_flow[empty][android]',
        'scenario_flow[empty][iphone]',
        'scenario_flow[happy][android]',
        'scenario_flow[happy][iphone]',
      ],
    );
  });
}
