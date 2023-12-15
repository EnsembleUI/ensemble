class JSException implements Exception {
  int line;
  int? column;
  String message;
  String? recovery;
  String? detailedError;

  // store the original error
  dynamic originalError;

  JSException(this.line, this.message,
      {this.column = 0, this.detailedError, this.recovery, this.originalError});

  @override
  String toString() {
    return 'Exception Occurred while running javascript code: Line: $line Message: $message.'
        ' Detailed Error: ${detailedError ?? ''}';
  }
}

class InvalidPropertyException implements Exception {
  String message;

  InvalidPropertyException(this.message);

  @override
  String toString() {
    return message;
  }
}
