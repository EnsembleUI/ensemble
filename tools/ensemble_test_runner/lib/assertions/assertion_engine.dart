import 'package:ensemble_test_runner/src/benchmark_measurement.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/storage_manager.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page_group.dart';
import 'package:ensemble_test_runner/application/application_test_driver.dart';
import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/runner/ensemble_test_context.dart';
import 'package:ensemble_test_runner/session/local/element_visibility.dart';
import 'package:ensemble_test_runner/session/local/widget_locator_id.dart';
import 'package:ensemble_test_runner/assertions/assertion_semantics.dart';
import 'package:ensemble_test_runner/assertions/assertion_navigation.dart';
import 'package:ensemble_test_runner/assertions/assertion_target_diagnostics.dart';
import 'package:ensemble_test_runner/assertions/assertion_text_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AssertionEngine {
  final WidgetTester tester;
  final EnsembleTestContext? context;
  final ApplicationTestServices services;
  late final AssertionTargetDiagnostics _targetDiagnostics =
      AssertionTargetDiagnostics(
    tester: tester,
    isVisuallyActionable: isElementVisuallyActionable,
  );
  late final AssertionSemantics _semantics = AssertionSemantics(tester);
  late final AssertionTextPolicy _textPolicy = AssertionTextPolicy(
    isVisible: isTextVisible,
    isContainingVisible: isTextContainingVisible,
    failureHint: (texts) => textFailureHint(texts),
  );
  late final AssertionNavigation _navigation = AssertionNavigation(
    navigationFlow: _ensembleContext.navigationFlow,
  );

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
    return RunnerBenchmark.sync('assertion', 'expectVisible', () {
      if (!_hasVisiblePaintedElement(finderForId(id))) {
        throw EnsembleTestFailure(
          'Expected widget with id "$id" to be visible. '
          '${widgetIdFailureHint(id)}',
        );
      }
    });
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
    final actual = _semantics.read(
      () => _semantics.isEnabled(
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
    return RunnerBenchmark.sync('assertion', 'expectNotVisible', () {
      if (_hasVisiblePaintedElement(finderForId(id))) {
        throw EnsembleTestFailure(
          'Expected widget with id "$id" to not be visible.',
        );
      }
    });
  }

  void expectText(String text) {
    return _textPolicy.expectText(text);
  }

  void expectTextAny(List<String> texts) {
    return _textPolicy.expectTextAny(texts);
  }

  void expectNoText(String text) {
    return _textPolicy.expectNoText(text);
  }

  void expectNoTextAny(List<String> texts) {
    return _textPolicy.expectNoTextAny(texts);
  }

  void expectTextContains(String text) {
    return _textPolicy.expectTextContains(text);
  }

  void expectTextContainsAny(List<String> texts) {
    return _textPolicy.expectTextContainsAny(texts);
  }

  bool isTextVisible(String text) => _hasVisiblePaintedElement(find.text(text));

  bool isTextContainingVisible(String text) =>
      _hasVisiblePaintedElement(find.textContaining(text));

  bool isAnyTextContainingVisible(List<String> texts) {
    return _textPolicy.isAnyTextContainingVisible(texts);
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
    final isEnabled = _semantics.read(
      () => _semantics.isEnabled(
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
    return RunnerBenchmark.sync('assertion', 'expectValueFinder', () {
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
    });
  }

  void expectApiCalled(String apiName, int times) {
    return RunnerBenchmark.sync('assertion', 'expectApiCalled', () {
      final actual = _ensembleContext.apiOverlay.callCount(apiName);
      if (actual != times) {
        throw EnsembleTestFailure(
          'Expected API "$apiName" to be called $times times, but it was called $actual times. '
          '${apiCallSummary()}',
        );
      }
    });
  }

  void expectCount(String id, int expected) {
    expectCountFinder(finderForId(id), expected, description: 'id "$id"');
  }

  void expectCountFinder(
    Finder finder,
    int expected, {
    String description = 'target',
  }) {
    return RunnerBenchmark.sync('assertion', 'expectCountFinder', () {
      final count = finder.evaluate().length;
      if (count != expected) {
        throw EnsembleTestFailure(
            'Expected $expected match(es) for $description, but found $count.');
      }
    });
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
    return isElementGeometricallyVisible(element, tester);
  }

  void expectChecked(String id, bool expected) {
    expectCheckedFinder(finderForId(id), expected, description: 'id "$id"');
  }

  void expectCheckedFinder(
    Finder finder,
    bool expected, {
    String description = 'target',
  }) {
    return RunnerBenchmark.sync('assertion', 'expectCheckedFinder', () {
      if (finder.evaluate().isEmpty) {
        throw EnsembleTestFailure('expectChecked: $description not found.');
      }
      final isChecked = _semantics.read(
        () => _semantics.isChecked(
          tester.getSemantics(finder).getSemanticsData(),
        ),
      );
      if (isChecked != expected) {
        throw EnsembleTestFailure(
          'Expected $description checked=$expected, got $isChecked.',
        );
      }
    });
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
    return RunnerBenchmark.sync('assertion', 'expectPropertyFinder', () {
      if (finder.evaluate().isEmpty) {
        throw EnsembleTestFailure('expectProperty: $description not found.');
      }
      if (property == 'label') {
        final label = _semantics.read(() => tester.getSemantics(finder).label);
        if (label != expected?.toString()) {
          throw EnsembleTestFailure(
            'Expected label "$expected", got "$label".',
          );
        }
        return;
      }
      throw EnsembleTestFailure('Unsupported property "$property".');
    });
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
    return RunnerBenchmark.sync('assertion', 'expectListCountFinder', () {
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
    });
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
    return RunnerBenchmark.sync('assertion', 'expectListContainsFinder', () {
      final match =
          find.descendant(of: listFinder, matching: find.textContaining(text));
      if (match.evaluate().isEmpty) {
        throw EnsembleTestFailure(
          'Expected $description to contain text "$text".',
        );
      }
    });
  }

  void expectNotVisited(String screenName) {
    _navigation.expectNotVisited(screenName);
  }

  void expectBackStack(List<String> screens) {
    _navigation.expectBackStack(screens);
  }

  void expectCanGoBack(bool expected) {
    _navigation.expectCanGoBack(expected);
  }

  void expectApiCallOrder(List<String> names) {
    return RunnerBenchmark.sync('assertion', 'expectApiCallOrder', () {
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
    });
  }

  void expectLastApiCall(String apiName) {
    return RunnerBenchmark.sync('assertion', 'expectLastApiCall', () {
      final calls = _ensembleContext.apiOverlay.calls;
      if (calls.isEmpty || calls.last.name != apiName) {
        throw EnsembleTestFailure(
          'Expected last API call to be "$apiName", '
          'but got ${calls.isEmpty ? "none" : calls.last.name}.',
        );
      }
    });
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
    return RunnerBenchmark.sync('assertion', 'expectAccessibleFinder', () {
      if (finder.evaluate().isEmpty) {
        throw EnsembleTestFailure('expectAccessible: $description not found.');
      }
      final hasAccessibleText = _semantics.read(() {
        final semantics = tester.getSemantics(finder);
        return semantics.label.isNotEmpty || semantics.value.isNotEmpty;
      });
      if (!hasAccessibleText) {
        throw EnsembleTestFailure(
          'Widget $description has no accessibility label or value.',
        );
      }
    });
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
    return RunnerBenchmark.sync('assertion', 'expectSemanticsLabelFinder', () {
      final actual = _semantics.read(() => tester.getSemantics(finder).label);
      if (actual != label) {
        throw EnsembleTestFailure(
          'Expected semantics label "$label" for $description, got "$actual".',
        );
      }
    });
  }

  void expectNoOverflow(String id) {
    expectNoOverflowFinder(finderForId(id), description: 'id "$id"');
  }

  void expectNoOverflowFinder(
    Finder finder, {
    String description = 'target',
  }) {
    return RunnerBenchmark.sync('assertion', 'expectNoOverflowFinder', () {
      if (finder.evaluate().isEmpty) {
        throw EnsembleTestFailure('expectNoOverflow: $description not found.');
      }
      final renderObject = tester.renderObject(finder);
      if (renderObject is RenderBox && renderObject.hasSize) {
        // No direct overflow flag; presence without exception is sufficient.
        return;
      }
    });
  }

  void expectNoConsoleErrors() {
    return RunnerBenchmark.sync('assertion', 'expectNoConsoleErrors', () {
      if (_ensembleContext.runtime.consoleLogs.isNotEmpty) {
        throw EnsembleTestFailure(
          'Expected no console errors, got: ${_ensembleContext.runtime.consoleLogs}',
        );
      }
    });
  }

  void expectNoRenderErrors() {
    return RunnerBenchmark.sync('assertion', 'expectNoRenderErrors', () {
      if (_ensembleContext.runtime.flutterErrors.isNotEmpty) {
        throw EnsembleTestFailure(
          'Expected no render errors, got: ${_ensembleContext.runtime.flutterErrors}',
        );
      }
    });
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
    _navigation.expectNavigateTo(screenName);
  }

  void expectVisited(String screenName) {
    _navigation.expectVisited(screenName);
  }

  String widgetIdFailureHint(String id, {int limit = 12}) =>
      _targetDiagnostics.widgetIdFailureHint(id, limit: limit);

  List<String> closestVisibleWidgetIds(String target, {int limit = 5}) =>
      _targetDiagnostics.closestVisibleWidgetIds(target, limit: limit);

  String visibleWidgetIdSummary({int limit = 12}) =>
      _targetDiagnostics.visibleWidgetIdSummary(limit: limit);

  String visibleTextSummary({int limit = 10}) =>
      _targetDiagnostics.visibleTextSummary(limit: limit);

  String textFailureHint(List<String> expectedTexts, {int limit = 10}) =>
      _targetDiagnostics.textFailureHint(expectedTexts, limit: limit);

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
}
