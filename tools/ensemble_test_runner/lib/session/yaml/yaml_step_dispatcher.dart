import 'package:ensemble_test_runner/models/ensemble_test_models.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';
import 'package:ensemble_test_runner/session/assertions/test_assertion.dart';
import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/local/local_execution_session.dart';
import 'package:ensemble_test_runner/session/yaml/yaml_step_migration_matrix.dart';
import 'package:ensemble_test_runner/vocabulary/test_step_vocabulary.dart';

/// Dispatches YAML [TestStep]s onto a [LocalTestExecutionSession].
///
/// Leaf UI / wait / assert steps go through the session API. Privileged,
/// lifecycle, and diagnostic steps call [LocalTestExecutionSession.executor]
/// directly — the same shared [TestStepExecutor] the session uses for acts.
///
/// Control-flow steps do **not** acquire the session leaf lock; they invoke
/// nested steps sequentially through this dispatcher.
class YamlStepDispatcher {
  YamlStepDispatcher({
    required this.session,
  });

  final LocalTestExecutionSession session;

  Future<void> execute(TestStep step) async {
    final canonical = TestStepVocabulary.resolveStepType(step.type);
    final path = YamlStepMigrationMatrix.pathFor(canonical) ??
        YamlStepMigrationMatrix.pathFor(step.type);

    if (path == YamlStepPath.control) {
      await _executeControl(step, canonical);
      return;
    }

    if (path == YamlStepPath.act) {
      final action = _actionForStep(step, canonical);
      final result = await session.act(action);
      if (!result.succeeded) {
        final error = result.error;
        if (error != null) throw error;
        throw EnsembleTestFailure('Action ${action.type} failed');
      }
      return;
    }

    if (path == YamlStepPath.wait) {
      final condition = _toWait(step, step.type) ??
          GenericWait(
            name: step.type,
            args: Map<String, dynamic>.from(step.args),
          );
      final result = await session.waitFor(
        condition,
        timeout: step.args['timeoutMs'] is int
            ? Duration(milliseconds: step.args['timeoutMs'] as int)
            : null,
      );
      if (!result.satisfied) {
        final error = result.error;
        if (error != null) throw error;
        throw EnsembleTestFailure('Wait ${condition.type} failed');
      }
      return;
    }

    if (path == YamlStepPath.assert_) {
      final assertion = _toAssertion(step, step.type);
      if (assertion != null) {
        final result = await session.assertCondition(assertion);
        if (!result.passed) {
          final error = result.error;
          if (error != null) throw error;
          throw EnsembleTestFailure(
            result.message ?? 'Assertion ${assertion.type} failed',
          );
        }
        return;
      }
    }

    // Privileged, lifecycle, diagnostic, and unmapped leaf types.
    await session.executor.execute(step.withCanonicalType(canonical));
  }

  Future<void> _executeControl(TestStep step, String canonical) async {
    switch (canonical) {
      case 'group':
        for (final nested in step.nestedSteps) {
          await execute(nested);
        }
      case 'repeat':
        final times = step.args['times'] as int? ?? 1;
        for (var i = 0; i < times; i++) {
          for (final nested in step.nestedSteps) {
            await execute(nested);
          }
        }
      case 'optional':
        try {
          for (final nested in step.nestedSteps) {
            await execute(nested);
          }
        } on EnsembleTestFailure {
          // Best-effort: missing banners / opportunistic waits must not fail.
        } on TestExecutionError {
          // Session path surfaces structured errors instead of EnsembleTestFailure.
        }
      case 'ifVisible':
        final target = _targetFromArgs(step.args);
        var visible = false;
        try {
          visible = session.resolver
              .resolveFinder(target)
              .evaluate()
              .any(session.assertions.isElementVisuallyActionable);
        } catch (_) {
          visible = false;
        }
        if (visible) {
          for (final nested in step.nestedSteps) {
            await execute(nested);
          }
        }
      default:
        await session.executor.execute(step);
    }
  }

  /// Plain id / vocabulary acts keep full YAML args (including timeoutMs).
  /// Structured locator / snapshot targets use typed [TestAction]s.
  TestAction _actionForStep(TestStep step, String canonical) {
    final target = _targetFromArgs(step.args);
    if (target.usesSnapshotElement ||
        target.occurrence != null ||
        target.locator != null) {
      return _toAction(step, canonical) ??
          GenericAction(
            name: canonical,
            args: Map<String, dynamic>.from(step.args),
          );
    }
    return GenericAction(
      name: canonical,
      args: Map<String, dynamic>.from(step.args),
    );
  }

  TestAction? _toAction(TestStep step, String type) {
    final id = step.args['id']?.toString();
    final target = _targetFromArgs(step.args);
    final timeoutMs = step.args['timeoutMs'] as int?;
    switch (type) {
      case 'tap':
        return TapAction(target, timeoutMs: timeoutMs);
      case 'doubleTap':
        return DoubleTapAction(target, timeoutMs: timeoutMs);
      case 'longPress':
        return LongPressAction(target, timeoutMs: timeoutMs);
      case 'enterText':
        return EnterTextAction(
          target: target,
          value: step.args['value']?.toString() ?? '',
        );
      case 'clearText':
        return ClearTextAction(target);
      case 'replaceText':
        return ReplaceTextAction(
          target: target,
          value: step.args['value']?.toString() ?? '',
        );
      case 'submitText':
        return SubmitTextAction(target);
      case 'focus':
        return FocusAction(target);
      case 'unfocus':
        return const UnfocusAction(ElementTarget());
      case 'toggle':
        return ToggleAction(target);
      case 'check':
        return CheckAction(target);
      case 'uncheck':
        return UncheckAction(target);
      case 'select':
        return SelectAction(
          target: target,
          value: step.args['value']?.toString() ?? '',
        );
      case 'selectIndex':
        return SelectIndexAction(
          target: target,
          index: step.args['index'] as int? ?? 0,
        );
      case 'setSlider':
        return SetSliderAction(
          target: target,
          value: (step.args['value'] as num?)?.toDouble() ?? 0,
        );
      case 'scrollUntilVisible':
        return ScrollUntilVisibleAction(
          target: target,
          scrollableId: step.args['scrollableId']?.toString(),
        );
      case 'scroll':
        return ScrollAction(
          target: id != null ? target : null,
          direction: _dir(step.args['direction']),
          distance: (step.args['distance'] as num?)?.toDouble(),
        );
      case 'swipe':
        return SwipeAction(
          direction: _dir(step.args['direction']),
          target: id != null ? target : null,
        );
      case 'drag':
        return DragAction(
          target: target,
          dx: (step.args['dx'] as num?)?.toDouble() ?? 0,
          dy: (step.args['dy'] as num?)?.toDouble() ?? 0,
        );
      case 'pullToRefresh':
        return PullToRefreshAction(target: id != null ? target : null);
      case 'chooseDate':
        return ChooseDateAction(
          target: target,
          value: step.args['value']?.toString() ?? '',
        );
      case 'chooseTime':
        return ChooseTimeAction(
          target: target,
          value: step.args['value']?.toString() ?? '',
        );
      default:
        return null;
    }
  }

  WaitCondition? _toWait(TestStep step, String type) {
    switch (type) {
      case 'wait':
      case 'pump':
        return PumpWait(
          duration: Duration(
            milliseconds:
                step.args['durationMs'] as int? ?? (type == 'pump' ? 0 : 500),
          ),
        );
      case 'settle':
        return SettleWait(
          timeout: step.args['timeoutMs'] is int
              ? Duration(milliseconds: step.args['timeoutMs'] as int)
              : null,
        );
      case 'waitFor':
        return ElementWait.target(_targetFromArgs(step.args));
      case 'waitForGone':
        return ElementWait.target(
          _targetFromArgs(step.args),
          gone: true,
        );
      case 'waitForText':
        return TextWait(
          text: step.args['text']?.toString(),
          anyOf:
              (step.args['anyOf'] as List?)?.map((e) => e.toString()).toList(),
        );
      case 'waitForNavigation':
        return ScreenWait(screen: step.args['screen']?.toString() ?? '');
      case 'waitForApi':
        return ApiWait(
          name: step.args['name']?.toString(),
          args: Map<String, dynamic>.from(step.args)..remove('name'),
        );
      default:
        return null;
    }
  }

  TestAssertion? _toAssertion(TestStep step, String type) {
    final target = _targetFromArgs(step.args);
    switch (type) {
      case 'expectVisible':
        return ElementVisibleAssertion.target(target);
      case 'expectNotVisible':
        return ElementVisibleAssertion.target(target, visible: false);
      case 'expectExists':
        return ElementExistsAssertion.target(target);
      case 'expectNotExists':
        return ElementExistsAssertion.target(target, exists: false);
      case 'expectEnabled':
        return ElementEnabledAssertion.target(target);
      case 'expectDisabled':
        return ElementEnabledAssertion.target(target, enabled: false);
      case 'expectScreen':
        return ScreenAssertion(
          screen: step.args['screen']?.toString() ??
              step.args['name']?.toString() ??
              '',
        );
      default:
        final domain = _assertDomain(type);
        return GenericAssertion(
          domain: domain,
          name: type,
          args: step.args,
        );
    }
  }

  ElementTarget _targetFromArgs(Map<String, dynamic> args) {
    final raw = args['target'];
    if (raw is Map) {
      return ElementTarget(
        locator: ElementLocator.fromJson(Map<String, dynamic>.from(raw)),
      );
    }
    return ElementTarget(testId: args['id']?.toString());
  }

  String _assertDomain(String type) {
    if (type.startsWith('expectApi')) return 'api';
    if (type.contains('Storage')) return 'storage';
    if (type.contains('Script') || type.contains('Console')) return 'script';
    if (type.contains('Screen') ||
        type.contains('Navigate') ||
        type.contains('Visited') ||
        type.contains('Back')) {
      return 'navigation';
    }
    if (type.contains('Error') ||
        type.contains('Overflow') ||
        type.contains('Accessible') ||
        type.contains('Semantics')) {
      return 'quality';
    }
    return 'ui';
  }

  SwipeDirection _dir(dynamic raw) {
    final name = raw?.toString() ?? 'down';
    return SwipeDirection.values.firstWhere(
      (d) => d.name == name,
      orElse: () => SwipeDirection.down,
    );
  }
}
