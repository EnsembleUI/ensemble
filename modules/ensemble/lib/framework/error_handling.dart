import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:source_span/source_span.dart';

class ConfigError extends EnsembleError {
  ConfigError(super.error);

  @override
  String toString() => 'Config Error: $error';
}

/// Language Error will be exposed on Studio
class LanguageError extends EnsembleError {
  LanguageError(super.error, {super.recovery, super.detailedError});

  @override
  String toString() => 'Language Error: $error\n$recovery';
}

/// Layout error will show on Studio
class LayoutError extends EnsembleError {
  LayoutError(super.error, {super.recovery, super.detailedError});

  @override
  String toString() => 'Layout Error: $error\n$recovery';
}

class StudioError extends EnsembleError {
  StudioError(super.error,
      {required this.errorId, super.recovery, super.detailedError});

  // the error id to be constructed into an external URL
  String errorId;

  get docUrl => getDocUrl(errorId);

  static getDocUrl(errorId) => 'https://docs.ensembleui.com/error/$errorId';
}

class CodeError extends EnsembleError {
  CodeError(JSException exception, SourceLocation? yamlLocation)
      : super(exception.message,
            line: exception.line,
            recovery: exception.recovery,
            detailedError: exception.detailedError) {
    line = yamlLocation?.line ?? 0;
    line = line! + exception.line;
    error =
        'Line: $line in YAML and Line: ${exception.line} within the code block. Error Message: $error';
  }
}

class RuntimeError extends EnsembleError {
  RuntimeError(super.error);

  @override
  String toString() => "Runtime Error: $error";
}

abstract class EnsembleError extends Error {
  EnsembleError(this.error, {this.line, this.recovery, this.detailedError});

  int? line;
  int? column;
  String error;
  String? recovery;
  String? detailedError;

  @override
  String toString() => "$error${recovery ?? ''}${detailedError ?? ''}";
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
