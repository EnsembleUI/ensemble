class LanguageError extends Error {
  LanguageError (this.error, {this.recovery});

  String error;
  String? recovery;

  @override
  String toString() {
    return 'Error: $error. ' + (recovery ?? '');
  }
}