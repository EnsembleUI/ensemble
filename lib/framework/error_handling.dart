import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:source_span/source_span.dart';

class ConfigError extends EnsembleError {
  ConfigError(super.error);

  @override
  String toString() => 'Config Error: $error';
}

/// Language Error will be exposed on Studio
class LanguageError extends EnsembleError {
  LanguageError(super.error, {super.recovery, super.detailError});

  @override
  String toString() => 'Language Error: $error\n$recovery';
}

/// Layout error will show on Studio
class LayoutError extends EnsembleError {
  LayoutError(super.error, {super.recovery, super.detailError});

  @override
  String toString() => 'Layout Error: $error\n$recovery';
}

class CodeError extends EnsembleError {
  CodeError(JSException exception, SourceLocation? yamlLocation)
      : super(exception.message,
            line: exception.line,
            recovery: exception.recovery,
            detailError: exception.detailedError) {
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
  EnsembleError(this.error, {this.line, this.recovery, this.detailError});

  int? line;
  int? column;
  String error;
  String? recovery;
  String? detailError;

  @override
  String toString() => "$error${recovery ?? ''}${detailError ?? ''}";
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
