import 'dart:convert';

import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds actionable diagnostics for assertion targets.
///
/// The visibility predicate is supplied by [AssertionEngine], so diagnostics
/// use the same route, opacity, viewport, and offstage rules as assertions.
class AssertionTargetDiagnostics {
  final WidgetTester tester;
  final bool Function(Element element) isVisuallyActionable;

  const AssertionTargetDiagnostics({
    required this.tester,
    required this.isVisuallyActionable,
  });

  String widgetIdFailureHint(String id, {int limit = 12}) {
    final matches = closestVisibleWidgetIds(id, limit: 5);
    final similar =
        matches.isEmpty ? '' : ' Closest visible ids: ${matches.join(', ')}.';
    return 'No visible widget matched this id.$similar '
        '${visibleWidgetIdSummary(limit: limit)} '
        '${_currentScreenSummary()} '
        'Hint: check that "$id" is on the current screen/state, or add a '
        'testId/id to the intended widget.';
  }

  List<String> closestVisibleWidgetIds(String target, {int limit = 5}) {
    final targetTokens = _idTokens(target);
    if (targetTokens.isEmpty) return const [];

    final scored = <({String id, int score})>[];
    for (final id in _visibleWidgetIds()) {
      if (id == target) continue;
      final candidateTokens = _idTokens(id);
      var score = 0;
      for (final token in targetTokens) {
        if (candidateTokens.contains(token)) {
          score += 3;
        } else if (candidateTokens.any(
          (candidate) =>
              candidate.startsWith(token) || token.startsWith(candidate),
        )) {
          score += 1;
        }
      }
      if (score > 0) scored.add((id: id, score: score));
    }

    scored.sort((a, b) {
      final score = b.score.compareTo(a.score);
      if (score != 0) return score;
      return a.id.compareTo(b.id);
    });
    return scored.take(limit).map((match) => match.id).toList();
  }

  String visibleWidgetIdSummary({int limit = 12}) {
    final ids = _visibleWidgetIds();
    if (ids.isEmpty) return 'No keyed test widgets are currently visible.';
    final shown = ids.take(limit).join(', ');
    final suffix = ids.length > limit ? ', ... (${ids.length} total)' : '';
    return 'Visible widget ids: $shown$suffix.';
  }

  String visibleTextSummary({int limit = 10}) {
    final texts = tester.allWidgets
        .whereType<Text>()
        .map((widget) => widget.data)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(limit)
        .toList();
    if (texts.isEmpty) return 'No Text widgets are currently visible.';
    return 'Visible text: ${texts.map(jsonEncode).join(', ')}.';
  }

  String textFailureHint(List<String> expectedTexts, {int limit = 10}) {
    final expected = _nonEmptyTexts(expectedTexts);
    final localeHint = expected.any(_containsNonAscii)
        ? ' Also verify that the test is running with the expected locale/translation.'
        : '';
    return '${visibleTextSummary(limit: limit)} '
        '${_currentScreenSummary()} '
        'Hint: check that the app is on the expected screen/state before this assertion.$localeHint';
  }

  List<String> _visibleWidgetIds() {
    final ids = <String>{};
    for (final element in tester.allElements) {
      if (!isVisuallyActionable(element)) continue;
      final id = readOwnedWidgetLocatorId(element);
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    return ids.toList()..sort();
  }

  List<String> _idTokens(String value) => value
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((token) => token.length >= 2)
      .toSet()
      .toList();

  List<String> _nonEmptyTexts(List<String> texts) {
    final candidates = texts
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (candidates.isEmpty) {
      throw EnsembleTestFailure('Text anyOf must not be empty.');
    }
    return candidates;
  }

  String _currentScreenSummary() {
    final screen = ScreenTracker().getCurrentScreenIdentifier();
    if (screen == null || screen.trim().isEmpty) {
      return 'Current screen: unknown.';
    }
    return 'Current screen: "${screen.trim()}".';
  }

  bool _containsNonAscii(String value) =>
      value.runes.any((codeUnit) => codeUnit > 127);
}
