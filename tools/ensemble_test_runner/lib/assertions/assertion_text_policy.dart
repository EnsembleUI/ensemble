import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/src/benchmark_measurement.dart';

/// Implements text matching rules shared by the assertion facade.
///
/// The policy receives visibility queries from [AssertionEngine], keeping
/// widget traversal and text matching separate without changing the public
/// assertion surface.
class AssertionTextPolicy {
  final bool Function(String text) isVisible;
  final bool Function(String text) isContainingVisible;
  final String Function(List<String> expectedTexts) failureHint;

  const AssertionTextPolicy({
    required this.isVisible,
    required this.isContainingVisible,
    required this.failureHint,
  });

  void expectText(String text) {
    return RunnerBenchmark.sync('assertion', 'expectText', () {
      if (!isVisible(text)) {
        throw EnsembleTestFailure(
          'Expected text "$text" to be visible. ${failureHint([text])}',
        );
      }
    });
  }

  void expectTextAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    for (final text in candidates) {
      if (isVisible(text)) return;
    }
    throw EnsembleTestFailure(
      'Expected one of these texts to be visible: '
      '${candidates.map((t) => '"$t"').join(', ')}. '
      '${failureHint(candidates)}',
    );
  }

  void expectNoText(String text) {
    if (isVisible(text)) {
      throw EnsembleTestFailure('Expected text "$text" to not be visible.');
    }
  }

  void expectNoTextAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    final visible = <String>[];
    for (final text in candidates) {
      if (isVisible(text)) visible.add(text);
    }
    if (visible.isNotEmpty) {
      throw EnsembleTestFailure(
        'Expected none of these texts to be visible, but found: '
        '${visible.map((t) => '"$t"').join(', ')}.',
      );
    }
  }

  void expectTextContains(String text) {
    if (!isContainingVisible(text)) {
      throw EnsembleTestFailure(
        'Expected text containing "$text". ${failureHint([text])}',
      );
    }
  }

  void expectTextContainsAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    for (final text in candidates) {
      if (isContainingVisible(text)) return;
    }
    throw EnsembleTestFailure(
      'Expected text containing one of: '
      '${candidates.map((t) => '"$t"').join(', ')}. '
      '${failureHint(candidates)}',
    );
  }

  bool isAnyTextContainingVisible(List<String> texts) {
    for (final text in _nonEmptyTexts(texts)) {
      if (isContainingVisible(text)) return true;
    }
    return false;
  }

  static List<String> _nonEmptyTexts(List<String> texts) {
    final candidates = texts
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      throw EnsembleTestFailure('Text anyOf must not be empty.');
    }
    return candidates;
  }
}
