import 'dart:convert';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:ensemble_test_runner/session/local/modal_route_lookup.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class AssertionEngine {
  final WidgetTester tester;
  final EnsembleTestContext? context;
  final ApplicationTestServices services;

  AssertionEngine({
    required this.tester,
    this.context,
    this.services = const ApplicationTestServices(),
  });

  EnsembleTestContext get _ensembleContext {
    final value = context;
    if (value == null) {
      throw EnsembleTestFailure(
        'This assertion requires an application capability that was not provided.',
      );
    }
    return value;
  }

  Finder finderForId(String id, {bool skipOffstage = true}) =>
      finderForLocatorId(id, skipOffstage: skipOffstage);

  Finder finderForIdIncludingOffstage(String id) =>
      finderForId(id, skipOffstage: false);

  /// First matching element that is on the current route and visually actionable.
  ///
  /// Used by screenshot highlights so we never annotate off-route / covered
  /// widgets while another screen is painted.
  Element? firstVisuallyActionableElement(
    Finder finder, {
    bool requireHitTestable = false,
  }) {
    final candidates = requireHitTestable
        ? finder.hitTestable().evaluate()
        : finder.evaluate();
    for (final element in candidates) {
      if (isElementVisuallyActionable(element)) {
        return element;
      }
    }
    return null;
  }

  /// Bounds for [firstVisuallyActionableElement], or null when none qualify.
  Rect? rectForVisuallyActionable(
    Finder finder, {
    bool requireHitTestable = false,
  }) {
    final element = firstVisuallyActionableElement(
      finder,
      requireHitTestable: requireHitTestable,
    );
    if (element == null) return null;
    final renderObject = element.renderObject;
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      return null;
    }
    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    if (!rect.isFinite || rect.isEmpty) return null;
    return rect;
  }

  /// Whether [element] is on the current modal route, not offstage, and on-screen.
  bool isElementVisuallyActionable(Element element) =>
      _isElementInViewport(element);

  void expectVisible(String id) {
    if (!_hasVisiblePaintedElement(finderForId(id))) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to be visible. '
        '${widgetIdFailureHint(id)}',
      );
    }
  }

  bool hasVisibleElement(Finder finder) => _hasVisiblePaintedElement(finder);

  void expectVisibleFinder(Finder finder, {bool visible = true}) {
    final actual = _hasVisiblePaintedElement(finder);
    if (actual != visible) {
      throw EnsembleTestFailure(
        'Expected resolved element to be ${visible ? 'visible' : 'not visible'}.',
      );
    }
  }

  void expectExistsFinder(Finder finder, {bool exists = true}) {
    final actual = finder.evaluate().isNotEmpty;
    if (actual != exists) {
      throw EnsembleTestFailure(
        'Expected resolved element to ${exists ? 'exist' : 'not exist'}.',
      );
    }
  }

  void expectEnabledFinder(Finder finder, {bool enabled = true}) {
    final matches = finder.evaluate().toList();
    if (matches.length != 1) {
      throw EnsembleTestFailure(
        'Enabled check requires exactly one resolved element; found ${matches.length}.',
      );
    }
    final actual = _readSemantics(
      () => _semanticsIsEnabled(
        tester.getSemantics(finder).getSemanticsData(),
      ),
    );
    if (actual != enabled) {
      throw EnsembleTestFailure(
        'Expected resolved element to be ${enabled ? 'enabled' : 'disabled'}.',
      );
    }
  }

  void expectNotVisible(String id) {
    if (_hasVisiblePaintedElement(finderForId(id))) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to not be visible.',
      );
    }
  }

  void expectText(String text) {
    if (!isTextVisible(text)) {
      throw EnsembleTestFailure(
        'Expected text "$text" to be visible. ${textFailureHint([text])}',
      );
    }
  }

  void expectTextAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    for (final text in candidates) {
      if (isTextVisible(text)) return;
    }
    throw EnsembleTestFailure(
      'Expected one of these texts to be visible: '
      '${candidates.map((t) => '"$t"').join(', ')}. '
      '${textFailureHint(candidates)}',
    );
  }

  void expectNoText(String text) {
    if (isTextVisible(text)) {
      throw EnsembleTestFailure('Expected text "$text" to not be visible.');
    }
  }

  void expectNoTextAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    final visible = <String>[];
    for (final text in candidates) {
      if (isTextVisible(text)) visible.add(text);
    }
    if (visible.isNotEmpty) {
      throw EnsembleTestFailure(
        'Expected none of these texts to be visible, but found: '
        '${visible.map((t) => '"$t"').join(', ')}.',
      );
    }
  }

  void expectTextContains(String text) {
    if (!isTextContainingVisible(text)) {
      throw EnsembleTestFailure(
        'Expected text containing "$text". ${textFailureHint([text])}',
      );
    }
  }

  void expectTextContainsAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    for (final text in candidates) {
      if (isTextContainingVisible(text)) return;
    }
    throw EnsembleTestFailure(
      'Expected text containing one of: '
      '${candidates.map((t) => '"$t"').join(', ')}. '
      '${textFailureHint(candidates)}',
    );
  }

  bool isTextVisible(String text) => _hasVisiblePaintedElement(find.text(text));

  bool isTextContainingVisible(String text) =>
      _hasVisiblePaintedElement(find.textContaining(text));

  bool isAnyTextContainingVisible(List<String> texts) {
    for (final text in _nonEmptyTexts(texts)) {
      if (isTextContainingVisible(text)) return true;
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

  void expectEnabled(String id) {
    _expectEnabledState(id, enabled: true);
  }

  void expectDisabled(String id) {
    _expectEnabledState(id, enabled: false);
  }

  void _expectEnabledState(String id, {required bool enabled}) {
    final finder = finderForId(id);
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to exist for enabled check.',
      );
    }
    final isEnabled = _readSemantics(
      () => _semanticsIsEnabled(
        tester.getSemantics(finder).getSemanticsData(),
      ),
    );
    if (isEnabled != enabled) {
      throw EnsembleTestFailure(
        'Expected widget "$id" to be ${enabled ? 'enabled' : 'disabled'}, '
        'but it was ${isEnabled ? 'enabled' : 'disabled'}.',
      );
    }
  }

  void expectApiNotCalled(String apiName) {
    final count = _ensembleContext.apiOverlay.callCount(apiName);
    if (count != 0) {
      throw EnsembleTestFailure(
        'Expected API "$apiName" not to be called, but it was called $count times.',
      );
    }
  }

  void expectValue(String id, dynamic expected) {
    expectValueFinder(finderForId(id), expected, description: 'id "$id"');
  }

  void expectValueFinder(
    Finder finder,
    dynamic expected, {
    String description = 'target',
  }) {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected $description to be visible for expectValue.',
      );
    }

    final editableFinder = find.descendant(
      of: finder,
      matching: find.byType(EditableText),
    );
    if (editableFinder.evaluate().isNotEmpty) {
      final editable = tester.widget<EditableText>(editableFinder);
      final actual = editable.controller.text;
      if (actual != expected?.toString()) {
        throw EnsembleTestFailure(
          'Expected input under $description to have value "$expected", but got "$actual".',
        );
      }
      return;
    }

    final textFieldFinder = find.descendant(
      of: finder,
      matching: find.byType(TextField),
    );
    if (textFieldFinder.evaluate().isNotEmpty) {
      final field = tester.widget<TextField>(textFieldFinder);
      final actual = field.controller?.text;
      if (actual != expected?.toString()) {
        throw EnsembleTestFailure(
          'Expected input under $description to have value "$expected", but got "$actual".',
        );
      }
      return;
    }

    throw EnsembleTestFailure(
      'No EditableText or TextField found under $description.',
    );
  }

  void expectApiCalled(String apiName, int times) {
    final actual = _ensembleContext.apiOverlay.callCount(apiName);
    if (actual != times) {
      throw EnsembleTestFailure(
        'Expected API "$apiName" to be called $times times, but it was called $actual times. '
        '${apiCallSummary()}',
      );
    }
  }

  void expectCount(String id, int expected) {
    expectCountFinder(finderForId(id), expected, description: 'id "$id"');
  }

  void expectCountFinder(
    Finder finder,
    int expected, {
    String description = 'target',
  }) {
    final count = finder.evaluate().length;
    if (count != expected) {
      throw EnsembleTestFailure(
          'Expected $expected match(es) for $description, but found $count.');
    }
  }

  void expectExists(String id) {
    if (finderForIdIncludingOffstage(id).evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to exist. ${widgetIdFailureHint(id)}',
      );
    }
  }

  void expectNotExists(String id) {
    if (finderForIdIncludingOffstage(id).evaluate().isNotEmpty) {
      throw EnsembleTestFailure('Expected widget with id "$id" to not exist.');
    }
  }

  bool _hasVisiblePaintedElement(Finder finder) {
    return finder.evaluate().any(_isElementInViewport);
  }

  bool _isElementInViewport(Element element) {
    // Never use ModalRoute.of — that registers InheritedWidget dependents on
    // every checked element and poisons Live-binding workers on navigation.
    if (!isUnderCurrentModalRoute(element)) return false;
    if (_isUnderOffstageAncestor(element)) return false;

    final renderObject = element.renderObject;
    if (renderObject is! RenderBox ||
        !renderObject.hasSize ||
        renderObject.size.isEmpty) {
      return false;
    }
    if (_effectiveOpacity(element) <= 0.01) return false;

    final topLeft = renderObject.localToGlobal(Offset.zero);
    final rect = topLeft & renderObject.size;
    if (!rect.isFinite || rect.isEmpty) return false;

    final viewport = tester.binding.renderViews.first.paintBounds;
    final visibleRect = rect.intersect(viewport);
    return visibleRect != Rect.zero &&
        visibleRect.width > 0 &&
        visibleRect.height > 0;
  }

  bool _isUnderOffstageAncestor(Element element) {
    var isOffstage = false;
    element.visitAncestorElements((ancestor) {
      final renderObject = ancestor.renderObject;
      if (renderObject is RenderOffstage && renderObject.offstage) {
        isOffstage = true;
        return false;
      }
      return true;
    });
    return isOffstage;
  }

  double _effectiveOpacity(Element element) {
    var opacity = 1.0;
    element.visitAncestorElements((ancestor) {
      final renderObject = ancestor.renderObject;
      if (renderObject is RenderOpacity) {
        opacity *= renderObject.opacity;
      } else if (renderObject != null &&
          renderObject.runtimeType.toString() == 'RenderAnimatedOpacity') {
        try {
          final animatedOpacity = (renderObject as dynamic).opacity;
          if (animatedOpacity is Animation<double>) {
            opacity *= animatedOpacity.value;
          } else if (animatedOpacity is double) {
            opacity *= animatedOpacity;
          }
        } catch (_) {
          // Keep the opacity already collected from other ancestors.
        }
      }
      return opacity > 0.01;
    });
    return opacity;
  }

  void expectChecked(String id, bool expected) {
    expectCheckedFinder(finderForId(id), expected, description: 'id "$id"');
  }

  void expectCheckedFinder(
    Finder finder,
    bool expected, {
    String description = 'target',
  }) {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectChecked: $description not found.');
    }
    final isChecked = _readSemantics(
      () => _semanticsIsChecked(
        tester.getSemantics(finder).getSemanticsData(),
      ),
    );
    if (isChecked != expected) {
      throw EnsembleTestFailure(
        'Expected $description checked=$expected, got $isChecked.',
      );
    }
  }

  // Flutter 3.47 exposes typed semantics flags through `flagsCollection`.
  // Keep the dynamic fallback for the package's supported Flutter 3.27+
  // range, where SemanticsData exposes the same values through `hasFlag`.
  bool _semanticsIsEnabled(SemanticsData data) {
    final dynamic compatibleData = data;
    try {
      return _semanticsFlagValue(compatibleData.flagsCollection.isEnabled) ==
          true;
    } on NoSuchMethodError {
      return compatibleData.hasFlag(SemanticsFlag.isEnabled) == true;
    }
  }

  bool _semanticsIsChecked(SemanticsData data) {
    final dynamic compatibleData = data;
    try {
      return _semanticsFlagValue(compatibleData.flagsCollection.isChecked) ==
          true;
    } on NoSuchMethodError {
      return compatibleData.hasFlag(SemanticsFlag.isChecked) == true;
    }
  }

  bool? _semanticsFlagValue(Object? value) {
    if (value is bool) return value;
    return switch (value?.toString().split('.').last) {
      'isTrue' || 'checked' => true,
      'isFalse' || 'unchecked' => false,
      _ => null,
    };
  }

  void expectProperty(String id, String property, dynamic expected) {
    expectPropertyFinder(
      finderForId(id),
      property,
      expected,
      description: 'id "$id"',
    );
  }

  void expectPropertyFinder(
    Finder finder,
    String property,
    dynamic expected, {
    String description = 'target',
  }) {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectProperty: $description not found.');
    }
    if (property == 'label') {
      final label = _readSemantics(() => tester.getSemantics(finder).label);
      if (label != expected?.toString()) {
        throw EnsembleTestFailure(
          'Expected label "$expected", got "$label".',
        );
      }
      return;
    }
    throw EnsembleTestFailure('Unsupported property "$property".');
  }

  void expectListCount({
    required String listId,
    required int expected,
    String? itemId,
    bool atLeast = false,
  }) {
    expectListCountFinder(
      finderForId(listId),
      expected: expected,
      itemFinder: itemId == null ? null : finderForId(itemId),
      atLeast: atLeast,
      description: 'list "$listId"',
    );
  }

  void expectListCountFinder(
    Finder listFinder, {
    required int expected,
    Finder? itemFinder,
    bool atLeast = false,
    String description = 'target list',
  }) {
    if (listFinder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectListCount: $description not found.');
    }
    final count = itemFinder != null
        ? find
            .descendant(of: listFinder, matching: itemFinder)
            .evaluate()
            .length
        : find
            .descendant(
                of: listFinder, matching: find.byWidgetPredicate((_) => true))
            .evaluate()
            .length;
    if (atLeast) {
      if (count < expected) {
        throw EnsembleTestFailure(
          'Expected at least $expected items in $description, found $count.',
        );
      }
      return;
    }
    if (count != expected) {
      throw EnsembleTestFailure(
        'Expected $expected items in $description, found $count.',
      );
    }
  }

  void expectListContains({required String listId, required String text}) {
    expectListContainsFinder(
      finderForId(listId),
      text,
      description: 'list "$listId"',
    );
  }

  void expectListContainsFinder(
    Finder listFinder,
    String text, {
    String description = 'target list',
  }) {
    final match =
        find.descendant(of: listFinder, matching: find.textContaining(text));
    if (match.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected $description to contain text "$text".',
      );
    }
  }

  void expectNotVisited(String screenName) {
    final flow = YamlTestSession.navigationFlow.flow;
    final visited = flow.contains(screenName);
    if (visited) {
      throw EnsembleTestFailure(
        'Expected screen "$screenName" not to be visited.',
      );
    }
  }

  void expectBackStack(List<String> screens) {
    final history = ScreenTracker()
        .screenHistory
        .map((s) => s.screenName ?? s.screenId)
        .whereType<String>()
        .toList();
    if (history.length < screens.length) {
      throw EnsembleTestFailure(
        'Back stack too short. Expected suffix $screens, got $history',
      );
    }
    final suffix = history.sublist(history.length - screens.length);
    if (!_deepEquals(suffix, screens)) {
      throw EnsembleTestFailure(
        'Expected back stack suffix $screens, got $suffix (full: $history)',
      );
    }
  }

  void expectCanGoBack(bool expected) {
    final canPop = ScreenTracker().screenHistory.isNotEmpty;
    if (canPop != expected) {
      throw EnsembleTestFailure(
        'Expected canGoBack=$expected, but history length is '
        '${ScreenTracker().screenHistory.length}.',
      );
    }
  }

  void expectApiCallOrder(List<String> names) {
    final actual =
        _ensembleContext.apiOverlay.calls.map((c) => c.name).toList();
    var index = 0;
    for (final name in names) {
      while (index < actual.length && actual[index] != name) {
        index++;
      }
      if (index >= actual.length) {
        throw EnsembleTestFailure(
          'Expected API call order $names, but got $actual',
        );
      }
      index++;
    }
  }

  void expectLastApiCall(String apiName) {
    final calls = _ensembleContext.apiOverlay.calls;
    if (calls.isEmpty || calls.last.name != apiName) {
      throw EnsembleTestFailure(
        'Expected last API call to be "$apiName", '
        'but got ${calls.isEmpty ? "none" : calls.last.name}.',
      );
    }
  }

  void expectConsoleLog(String contains) {
    final logs = _ensembleContext.runtime.consoleLogs;
    if (!logs.any((l) => l.contains(contains))) {
      throw EnsembleTestFailure(
        'Expected console log containing "$contains", got: $logs',
      );
    }
  }

  void expectAccessible(String id) {
    expectAccessibleFinder(finderForId(id), description: 'id "$id"');
  }

  void expectAccessibleFinder(
    Finder finder, {
    String description = 'target',
  }) {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectAccessible: $description not found.');
    }
    final hasAccessibleText = _readSemantics(() {
      final semantics = tester.getSemantics(finder);
      return semantics.label.isNotEmpty || semantics.value.isNotEmpty;
    });
    if (!hasAccessibleText) {
      throw EnsembleTestFailure(
        'Widget $description has no accessibility label or value.',
      );
    }
  }

  void expectSemanticsLabel(String id, String label) {
    expectSemanticsLabelFinder(
      finderForId(id),
      label,
      description: 'id "$id"',
    );
  }

  void expectSemanticsLabelFinder(
    Finder finder,
    String label, {
    String description = 'target',
  }) {
    final actual = _readSemantics(() => tester.getSemantics(finder).label);
    if (actual != label) {
      throw EnsembleTestFailure(
        'Expected semantics label "$label" for $description, got "$actual".',
      );
    }
  }

  T _readSemantics<T>(T Function() read) {
    final handle = tester.ensureSemantics();
    try {
      return read();
    } finally {
      handle.dispose();
    }
  }

  void expectNoOverflow(String id) {
    expectNoOverflowFinder(finderForId(id), description: 'id "$id"');
  }

  void expectNoOverflowFinder(
    Finder finder, {
    String description = 'target',
  }) {
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectNoOverflow: $description not found.');
    }
    final renderObject = tester.renderObject(finder);
    if (renderObject is RenderBox && renderObject.hasSize) {
      // No direct overflow flag; presence without exception is sufficient.
      return;
    }
  }

  void expectNoConsoleErrors() {
    if (_ensembleContext.runtime.consoleLogs.isNotEmpty) {
      throw EnsembleTestFailure(
        'Expected no console errors, got: ${_ensembleContext.runtime.consoleLogs}',
      );
    }
  }

  void expectNoRenderErrors() {
    if (_ensembleContext.runtime.flutterErrors.isNotEmpty) {
      throw EnsembleTestFailure(
        'Expected no render errors, got: ${_ensembleContext.runtime.flutterErrors}',
      );
    }
  }

  void expectErrorRecorded(String? contains) {
    final errors = _ensembleContext.runtime.flutterErrors;
    if (errors.isEmpty) {
      throw EnsembleTestFailure('Expected a recorded error, but none found.');
    }
    if (contains != null && !errors.any((e) => e.contains(contains))) {
      throw EnsembleTestFailure(
        'Expected error containing "$contains", got: $errors',
      );
    }
  }

  void expectStorage(String key, dynamic expected) {
    final actual = StorageManager().read(key);
    if (actual != expected) {
      throw EnsembleTestFailure(
        'Expected storage "$key" to equal "$expected", but got "$actual".',
      );
    }
  }

  ScopeManager? activeScope() => _activeScope();

  void expectNavigateTo(String screenName) {
    final tracker = ScreenTracker();
    if (!tracker.isScreenVisible(screenName: screenName) &&
        !tracker.isScreenVisible(screenId: screenName)) {
      final current = tracker.getCurrentScreenIdentifier();
      final history = tracker.screenHistory
          .map((s) => s.screenName ?? s.screenId)
          .whereType<String>()
          .toList();
      throw EnsembleTestFailure(
        'Expected navigation to "$screenName", but current screen is "$current". '
        'History: $history. Navigation flow: ${YamlTestSession.navigationFlow.flow}',
      );
    }
  }

  void expectVisited(String screenName) {
    final flow = YamlTestSession.navigationFlow.flow;
    final visited = flow.contains(screenName);
    if (!visited) {
      throw EnsembleTestFailure(
        'Expected screen "$screenName" in navigation history, but visited '
        '$flow',
      );
    }
  }

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

  List<String> _visibleWidgetIds() {
    final ids = <String>{};
    for (final element in tester.allElements) {
      if (!isElementVisuallyActionable(element)) continue;
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

  String _currentScreenSummary() {
    final screen = ScreenTracker().getCurrentScreenIdentifier();
    if (screen == null || screen.trim().isEmpty) {
      return 'Current screen: unknown.';
    }
    return 'Current screen: "${screen.trim()}".';
  }

  bool _containsNonAscii(String value) =>
      value.runes.any((codeUnit) => codeUnit > 127);

  String apiCallSummary({int limit = 10}) {
    final calls = _ensembleContext.apiOverlay.calls;
    if (calls.isEmpty) return 'No API calls were recorded.';
    final names = calls.take(limit).map((call) => call.name).join(', ');
    final suffix = calls.length > limit ? ', ... (${calls.length} total)' : '';
    return 'Recorded API calls: $names$suffix.';
  }

  ScopeManager? _activeScope() {
    for (final element in find.byType(DataScopeWidget).evaluate()) {
      final scope = DataScopeWidget.getScope(element);
      if (scope != null) return scope;
    }
    for (final element in find.byType(PageGroupWidget).evaluate()) {
      final scope = PageGroupWidget.getScope(element);
      if (scope != null) return scope;
    }
    return null;
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (a == b) return true;

    final normalizedA = _normalizeForCompare(a);
    final normalizedB = _normalizeForCompare(b);

    if (normalizedA is Map && normalizedB is Map) {
      if (normalizedA.length != normalizedB.length) return false;
      for (final key in normalizedA.keys) {
        if (!normalizedB.containsKey(key)) return false;
        if (!_deepEquals(normalizedA[key], normalizedB[key])) return false;
      }
      return true;
    }

    if (normalizedA is List && normalizedB is List) {
      if (normalizedA.length != normalizedB.length) return false;
      for (var i = 0; i < normalizedA.length; i++) {
        if (!_deepEquals(normalizedA[i], normalizedB[i])) return false;
      }
      return true;
    }

    return false;
  }

  dynamic _normalizeForCompare(dynamic value) {
    if (value == null) return null;
    if (value is Map) {
      return value.map(
        (key, val) => MapEntry(key.toString(), _normalizeForCompare(val)),
      );
    }
    if (value is List) {
      return value.map(_normalizeForCompare).toList();
    }
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        try {
          return _normalizeForCompare(json.decode(trimmed));
        } catch (_) {}
      }
    }
    return value;
  }
}
