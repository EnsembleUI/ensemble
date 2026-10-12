import 'package:ensemble_test_runner/models/test_document_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accepts the declared test document root fields', () {
    expect(
      TestDocumentKeys.unsupportedRootKeys(
        TestDocumentKeys.supportedRootKeys,
      ),
      isEmpty,
    );
  });

  test('reports unsupported keys as strings in source order', () {
    expect(
      TestDocumentKeys.unsupportedRootKeys(['custom', 42, 'other']),
      ['custom', '42', 'other'],
    );
  });
}
