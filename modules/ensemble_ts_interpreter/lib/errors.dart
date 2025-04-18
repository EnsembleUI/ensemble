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
    return 'Exception occurred while running JavaScript code: '
        'Line: $line '
        'Message: $message. '
        '${detailedError != null ? 'Detailed Error: $detailedError. ' : ''}'
        '${recovery != null ? 'Recovery: $recovery .' : ''}';
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
