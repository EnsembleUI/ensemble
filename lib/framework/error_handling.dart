import 'package:jsparser/jsparser.dart';

class ConfigError extends EnsembleError {
  ConfigError(super.error);

  @override
  String toString() => 'Config Error: $error';
}


/// Language Error will be exposed on Studio
class LanguageError extends EnsembleError {
  LanguageError (super.error, {super.recovery, super.detailError});

  @override
  String toString() => 'Language Error: $error\n$recovery';
}

class CodeError extends EnsembleError {
  CodeError(Object input): super(
    input is ParseError ? input.message.toString() : input.toString()
  ) {
    if (input is ParseError) {
      recovery = "Line ${input.line}. Position ${input.startOffset}-${input.endOffset}.";
    }
  }

  @override
  String toString() => "Code Error: $error\n$recovery";

}

class RuntimeError extends EnsembleError {
  RuntimeError(super.error);

  @override
  String toString() => "Runtime Error: $error";
}

abstract class EnsembleError extends Error {
  EnsembleError(
    this.error, {
    this.recovery,
    this.detailError
  });
  String error;
  String? recovery;
  String? detailError;

  @override
  String toString() => "$error\n$recovery\n$detailError";
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