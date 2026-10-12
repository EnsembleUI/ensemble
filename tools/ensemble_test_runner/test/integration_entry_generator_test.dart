import 'package:ensemble_test_runner/cli/integration_entry_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('wraps an application entry without rewriting its source', () {
    const sourcePath = 'test/custom_entry.dart';
    const source = '''
import 'package:ensemble_test_runner/entry/application_test_entry.dart';
Future<void> main() => runApplicationTests();
''';

    final generated = IntegrationEntryGenerator.generate(
      sourceRelativePath: sourcePath,
      source: source,
      packageName: () => 'sample_app',
      sourceHasApplicationEntry: true,
    );

    expect(generated?.relativePath, 'integration_test/custom_entry.dart');
    expect(generated?.contents, contains("import '../test/custom_entry.dart'"));
    expect(generated?.contents, contains('application_tests.main()'));
    expect(source, contains('runApplicationTests()'));
  });

  test('does not generate a wrapper for a valid integration entry', () {
    final generated = IntegrationEntryGenerator.generate(
      sourceRelativePath: 'integration_test/custom_entry.dart',
      source: 'Future<void> main() => runApplicationIntegrationTests();',
      packageName: () => 'sample_app',
      sourceHasApplicationEntry: true,
    );

    expect(generated, isNull);
  });

  test('recognizes the generic application test entry', () {
    final generated = IntegrationEntryGenerator.generate(
      sourceRelativePath: 'test/custom_entry.dart',
      source: 'Future<void> main() => runApplicationTests();',
      packageName: () => 'sample_app',
      sourceHasApplicationEntry: true,
    );

    expect(generated?.contents, contains("import '../test/custom_entry.dart'"));
    expect(generated?.contents, contains('application_tests.main()'));
  });

  test('uses the validated entry classification without rescanning source', () {
    final generated = IntegrationEntryGenerator.generate(
      sourceRelativePath: 'test/custom_entry.dart',
      source: 'Future<void> main() => runApplicationTests();',
      packageName: () => 'sample_app',
      sourceHasApplicationEntry: false,
    );

    expect(
      generated?.contents,
      contains('runApplicationIntegrationTests()'),
    );
    expect(generated?.contents, isNot(contains('application_tests.main()')));
  });

  test('does not resolve package name for an existing integration entry', () {
    final generated = IntegrationEntryGenerator.generate(
      sourceRelativePath: 'integration_test/custom_entry.dart',
      source: 'Future<void> main() => runApplicationIntegrationTests();',
      packageName: () => throw StateError('package name should stay lazy'),
      sourceHasApplicationEntry: true,
    );

    expect(generated, isNull);
  });
}
