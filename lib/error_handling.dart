class ConfigError extends Error {
  ConfigError(this.error);
  final String error;

  @override
  String toString() => 'Config Error: $error';
}


/// Language Error will be exposed on Studio
class LanguageError extends Error {
  LanguageError (this.error, {this.recovery});

  String error;
  String? recovery;

  @override
  String toString() {
    return 'Error: $error. ' + (recovery ?? '');
  }
}


/// All Exceptions will be written to a running log of some sort
class RuntimeException implements Exception {
  RuntimeException(this.message);
  String message;

  @override
  String toString() {
    return 'Exception: $message';
  }
}