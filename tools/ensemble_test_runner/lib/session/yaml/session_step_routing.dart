import 'package:ensemble_test_runner/session/yaml/yaml_step_path.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

/// Derives [YamlStepPath] from [TestStepRegistry] categories.
///
/// Name-level overrides handle categories that mix lifecycle and assertions
/// (e.g. [TestStepCategory.navigation] contains both `goBack` and `expect*`).
///
/// ## Adding a new operation (minimal touch set)
///
/// 1. Register the step in [TestStepRegistry] / vocabulary (routing + caps).
/// 2. Prefer [GenericAction] / [GenericWait] / [GenericAssertion] so YAML and
///    session APIs reuse [TestStepExecutor] without new sealed subtypes.
/// 3. Add a typed [TestAction] subtype only when the session API needs
///    first-class fields; then map it in [YamlStepDispatcher] and
///    [LocalActionExecutor] (and set [TestAction.primaryTarget]).
///
/// Do not invent a parallel executor — leaf work stays on [TestStepExecutor].
abstract final class SessionStepRouting {
  SessionStepRouting._();

  /// Session execution path for a registry YAML key, or null if unknown.
  static YamlStepPath? pathFor(String stepType) {
    final entry = TestStepRegistry.entries[stepType];
    if (entry == null) return null;

    switch (stepType) {
      case 'goBack':
        return YamlStepPath.lifecycle;
      case 'logApiCalls':
        return YamlStepPath.diagnostic;
    }

    return pathForCategory(entry.category, stepType);
  }

  static YamlStepPath pathForCategory(
    TestStepCategory category,
    String stepType,
  ) {
    switch (category) {
      case TestStepCategory.lifecycle:
        return YamlStepPath.lifecycle;
      case TestStepCategory.interaction:
      case TestStepCategory.formControl:
      case TestStepCategory.gesture:
        return YamlStepPath.act;
      case TestStepCategory.wait:
        return YamlStepPath.wait;
      case TestStepCategory.uiAssertion:
      case TestStepCategory.valueAssertion:
      case TestStepCategory.listAssertion:
      case TestStepCategory.apiAssertion:
      case TestStepCategory.quality:
        return YamlStepPath.assert_;
      case TestStepCategory.navigation:
        if (stepType.startsWith('expect')) {
          return YamlStepPath.assert_;
        }
        return YamlStepPath.lifecycle;
      case TestStepCategory.apiMock:
      case TestStepCategory.runtime:
      case TestStepCategory.network:
        return YamlStepPath.privileged;
      case TestStepCategory.storage:
      case TestStepCategory.script:
        if (stepType.startsWith('expect')) {
          return YamlStepPath.assert_;
        }
        return YamlStepPath.privileged;
      case TestStepCategory.control:
        return YamlStepPath.control;
      case TestStepCategory.debug:
        return YamlStepPath.diagnostic;
    }
  }

  /// Canonical UI action names (session.act / permissions.actions).
  static Set<String> uiActionNames() {
    return TestStepRegistry.entries.entries
        .where((e) => pathFor(e.key) == YamlStepPath.act)
        .map((e) => e.value.executorCanonical ?? e.key)
        .toSet();
  }

  /// Assertion domains used by [SessionPermissions] / capabilities.
  static const Set<String> assertionDomains = {
    'ui',
    'navigation',
    'api',
    'storage',
    'script',
    'quality',
  };

  /// Wait kinds used by [WaitCondition.waitKind] permission checks.
  static const Set<String> waitKinds = {
    'pump',
    'settle',
    'uiElement',
    'text',
    'navigation',
    'api',
  };

  /// Actions omitted from [SessionPermissions.restrictedUi].
  static const Set<String> restrictedUiExclusions = {
    'setSlider',
    'chooseDate',
    'chooseTime',
    'pullToRefresh',
  };

  static Set<String> restrictedUiActionNames() =>
      uiActionNames().difference(restrictedUiExclusions);
}
