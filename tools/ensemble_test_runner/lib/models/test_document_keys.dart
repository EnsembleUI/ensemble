/// Root fields accepted by a single test document.
///
/// Parsing, validation, and setup diagnostics share this contract so they do
/// not drift when the document format changes.
abstract final class TestDocumentKeys {
  static const supportedRootKeys = <String>{
    'id',
    'type',
    'feature',
    'tags',
    'description',
    'owner',
    'priority',
    'parallel',
    'retry',
    'startScreen',
    'startScreenInputs',
    'session',
    'profiles',
    'initialState',
    'setup',
    'mocks',
    'scenarios',
    'steps',
  };

  static List<String> unsupportedRootKeys(Iterable<Object?> keys) => keys
      .map((key) => key.toString())
      .where((key) => !supportedRootKeys.contains(key))
      .toList();
}
