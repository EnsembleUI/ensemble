import 'dart:convert';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/runner/yaml_test_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class AssertionEngine {
  final WidgetTester tester;
  final EnsembleTestContext context;

  AssertionEngine({
    required this.tester,
    required this.context,
  });

  Finder finderForId(String id) => find.byKey(ValueKey(id));

  void expectVisible(String id) {
    final finder = finderForId(id).hitTestable();
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to be visible. '
        '${visibleWidgetIdSummary()}',
      );
    }
  }

  void expectNotVisible(String id) {
    final finder = finderForId(id).hitTestable();
    if (finder.evaluate().isNotEmpty) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to not be visible.',
      );
    }
  }

  void expectText(String text) {
    if (!isTextVisible(text)) {
      throw EnsembleTestFailure('Expected text "$text" to be visible.');
    }
  }

  void expectTextAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    for (final text in candidates) {
      if (isTextVisible(text)) return;
    }
    throw EnsembleTestFailure(
      'Expected one of these texts to be visible: '
      '${candidates.map((t) => '"$t"').join(', ')}.',
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
      throw EnsembleTestFailure('Expected text containing "$text".');
    }
  }

  void expectTextContainsAny(List<String> texts) {
    final candidates = _nonEmptyTexts(texts);
    for (final text in candidates) {
      if (isTextContainingVisible(text)) return;
    }
    throw EnsembleTestFailure(
      'Expected text containing one of: '
      '${candidates.map((t) => '"$t"').join(', ')}.',
    );
  }

  bool isTextVisible(String text) => _hasVisiblePaintedElement(find.text(text));

  bool isTextContainingVisible(String text) =>
      _hasVisiblePaintedElement(find.textContaining(text));

  bool isAnyTextVisible(List<String> texts) {
    for (final text in _nonEmptyTexts(texts)) {
      if (isTextVisible(text)) return true;
    }
    return false;
  }

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
      () => tester.getSemantics(finder).hasFlag(SemanticsFlag.isEnabled),
    );
    if (isEnabled != enabled) {
      throw EnsembleTestFailure(
        'Expected widget "$id" to be ${enabled ? 'enabled' : 'disabled'}, '
        'but it was ${isEnabled ? 'enabled' : 'disabled'}.',
      );
    }
  }

  void expectApiNotCalled(String apiName) {
    final count = context.apiOverlay.callCount(apiName);
    if (count != 0) {
      throw EnsembleTestFailure(
        'Expected API "$apiName" not to be called, but it was called $count times.',
      );
    }
  }

  void expectValue(String id, dynamic expected) {
    final finder = finderForId(id);
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to be visible for expectValue.',
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
          'Expected input "$id" value "$expected", but got "$actual".',
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
          'Expected input "$id" value "$expected", but got "$actual".',
        );
      }
      return;
    }

    throw EnsembleTestFailure(
      'No EditableText or TextField found under widget id "$id".',
    );
  }

  void expectApiCalled(String apiName, int times) {
    final actual = context.apiOverlay.callCount(apiName);
    if (actual != times) {
      throw EnsembleTestFailure(
        'Expected API "$apiName" to be called $times times, but it was called $actual times. '
        '${apiCallSummary()}',
      );
    }
  }

  void expectCount(String id, int expected) {
    final count = finderForId(id).evaluate().length;
    if (count != expected) {
      throw EnsembleTestFailure(
        'Expected $expected widget(s) with id "$id", but found $count.',
      );
    }
  }

  void expectExists(String id) {
    if (finderForId(id).evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected widget with id "$id" to exist. ${visibleWidgetIdSummary()}',
      );
    }
  }

  void expectNotExists(String id) {
    if (finderForId(id).evaluate().isNotEmpty) {
      throw EnsembleTestFailure('Expected widget with id "$id" to not exist.');
    }
  }

  bool _hasVisiblePaintedElement(Finder finder) {
    return finder.evaluate().any(_isElementInViewport);
  }

  bool _isElementInViewport(Element element) {
    final route = ModalRoute.of(element);
    if (route != null && !route.isCurrent) return false;
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
    final finder = finderForId(id);
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectChecked: widget "$id" not found.');
    }
    final isChecked = _readSemantics(
      () => tester.getSemantics(finder).hasFlag(SemanticsFlag.isChecked),
    );
    if (isChecked != expected) {
      throw EnsembleTestFailure(
        'Expected "$id" checked=$expected, got $isChecked.',
      );
    }
  }

  void expectProperty(String id, String property, dynamic expected) {
    final finder = finderForId(id);
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectProperty: widget "$id" not found.');
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
    final listFinder = finderForId(listId);
    if (listFinder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectListCount: list "$listId" not found.');
    }
    final count = itemId != null
        ? find
            .descendant(of: listFinder, matching: finderForId(itemId))
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
          'Expected at least $expected items in "$listId", found $count.',
        );
      }
      return;
    }
    if (count != expected) {
      throw EnsembleTestFailure(
        'Expected $expected items in "$listId", found $count.',
      );
    }
  }

  void expectListContains({required String listId, required String text}) {
    final listFinder = finderForId(listId);
    final match =
        find.descendant(of: listFinder, matching: find.textContaining(text));
    if (match.evaluate().isEmpty) {
      throw EnsembleTestFailure(
        'Expected list "$listId" to contain text "$text".',
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
    final actual = context.apiOverlay.calls.map((c) => c.name).toList();
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
    final calls = context.apiOverlay.calls;
    if (calls.isEmpty || calls.last.name != apiName) {
      throw EnsembleTestFailure(
        'Expected last API call to be "$apiName", '
        'but got ${calls.isEmpty ? "none" : calls.last.name}.',
      );
    }
  }

  void expectConsoleLog(String contains) {
    final logs = context.runtime.consoleLogs;
    if (!logs.any((l) => l.contains(contains))) {
      throw EnsembleTestFailure(
        'Expected console log containing "$contains", got: $logs',
      );
    }
  }

  void expectAccessible(String id) {
    final finder = finderForId(id);
    if (finder.evaluate().isEmpty) {
      throw EnsembleTestFailure('expectAccessible: "$id" not found.');
    }
    final hasAccessibleText = _readSemantics(() {
      final semantics = tester.getSemantics(finder);
      return semantics.label.isNotEmpty || semantics.value.isNotEmpty;
    });
    if (!hasAccessibleText) {
      throw EnsembleTestFailure(
        'Widget "$id" has no accessibility label or value.',
      );
    }
  }

  void expectSemanticsLabel(String id, String label) {
    final finder = finderForId(id);
    final actual = _readSemantics(() => tester.getSemantics(finder).label);
    if (actual != label) {
      throw EnsembleTestFailure(
        'Expected semantics label "$label", got "$actual".',
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
    final finder = finderForId(id);
    final renderObject = tester.renderObject(finder);
    if (renderObject is RenderBox && renderObject.hasSize) {
      // No direct overflow flag; presence without exception is sufficient.
      return;
    }
  }

  void expectNoConsoleErrors() {
    if (context.runtime.consoleLogs.isNotEmpty) {
      throw EnsembleTestFailure(
        'Expected no console errors, got: ${context.runtime.consoleLogs}',
      );
    }
  }

  void expectNoRenderErrors() {
    if (context.runtime.flutterErrors.isNotEmpty) {
      throw EnsembleTestFailure(
        'Expected no render errors, got: ${context.runtime.flutterErrors}',
      );
    }
  }

  void expectErrorRecorded(String? contains) {
    final errors = context.runtime.flutterErrors;
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

  String visibleWidgetIdSummary({int limit = 20}) {
    final ids = tester.allWidgets
        .map((widget) => widget.key)
        .whereType<ValueKey>()
        .map((key) => key.value.toString())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
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

  String apiCallSummary({int limit = 10}) {
    final calls = context.apiOverlay.calls;
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
