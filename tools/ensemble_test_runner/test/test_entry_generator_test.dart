import 'package:ensemble_test_runner/cli/test_entry_generator.dart';
import 'package:ensemble_test_runner/cli/entry_source_transformer.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a package name from already loaded pubspec content', () {
    expect(
      TestEntryGenerator.packageNameFromPubspec('name: sample_app\n'),
      'sample_app',
    );
  });

  test('reads quoted package names from pubspec YAML', () {
    expect(
      TestEntryGenerator.packageNameFromPubspec('name: "sample_app"\n'),
      'sample_app',
    );
    expect(
      TestEntryGenerator.packageNameFromPubspec('name: \'sample_app\'\n'),
      'sample_app',
    );
  });

  test('requires the package name at the pubspec root as a string', () {
    expect(
      () =>
          TestEntryGenerator.packageNameFromPubspec('flutter:\n  name: app\n'),
      throwsStateError,
    );
    expect(
      () => TestEntryGenerator.packageNameFromPubspec('name: true\n'),
      throwsStateError,
    );
  });

  test('generates the widget entry template', () {
    final contents = TestEntryGenerator.generate(
      mode: ExecutionMode.widget,
      packageName: 'sample_app',
    );

    expect(contents, contains('runEnsembleTests('));
    expect(contents,
        contains('package:sample_app/generated/ensemble_modules.dart'));
  });

  test('adapts an existing widget entry for integration mode', () {
    const source = '''
import 'package:ensemble_test_runner/entry/ensemble_test_entry.dart';
Future<void> main() => runEnsembleTests();
''';

    final contents = TestEntryGenerator.generate(
      mode: ExecutionMode.integration,
      packageName: 'sample_app',
      widgetEntrySource: source,
    );

    expect(contents, contains('ensemble_integration_test_entry.dart'));
    expect(contents, contains('runEnsembleIntegrationTests()'));
  });

  test('does not accept the removed legacy runner entry', () {
    const legacySource = '''
import 'package:ensemble_test_runner/entry/ensemble_test_entry.dart';
Future<void> main() => runEnsembleYamlTests();
''';

    expect(
      EntrySourceTransformer.ensembleWidgetEntryPoints,
      ['runEnsembleTests'],
    );
    expect(
      EntrySourceTransformer.adaptEntryForIntegration(legacySource),
      isNull,
    );
    final generated = TestEntryGenerator.generate(
      mode: ExecutionMode.integration,
      packageName: 'sample_app',
      widgetEntrySource: legacySource,
    );
    expect(generated, contains('runEnsembleIntegrationTests('));
    expect(generated, isNot(contains('runEnsembleYamlTests')));
  });

  test('uses integration template when source cannot be adapted', () {
    final contents = TestEntryGenerator.generate(
      mode: ExecutionMode.integration,
      packageName: 'sample_app',
      widgetEntrySource: 'Future<void> main() async {}',
    );

    expect(contents, contains('runEnsembleIntegrationTests('));
    expect(contents,
        contains('package:sample_app/generated/ensemble_modules.dart'));
  });

  test('uses integration template when entry names only occur in strings', () {
    const source = '''
const generatedMarker = 'runEnsembleTests()';
Future<void> main() async {}
''';

    final contents = TestEntryGenerator.generate(
      mode: ExecutionMode.integration,
      packageName: 'sample_app',
      widgetEntrySource: source,
    );

    expect(contents, contains('runEnsembleIntegrationTests('));
    expect(contents, isNot(source));
  });

  test('preserves an existing integration entry alias', () {
    const source = '''
import 'package:ensemble_test_runner/entry/ensemble_integration_test_entry.dart';
Future<void> main() => runEnsembleIntegrationTests();
''';

    expect(
      TestEntryGenerator.generate(
        mode: ExecutionMode.integration,
        packageName: 'sample_app',
        widgetEntrySource: source,
      ),
      source,
    );
  });
}
