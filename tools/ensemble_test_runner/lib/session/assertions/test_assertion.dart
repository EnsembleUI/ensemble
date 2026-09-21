import 'package:ensemble_test_runner/session/errors/test_execution_error.dart';
import 'package:ensemble_test_runner/session/actions/test_action.dart';

/// Deterministic assertion request.
sealed class TestAssertion {
  const TestAssertion();

  String get type;
  String get domain;

  Map<String, dynamic> toJson();

  static TestAssertion fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    final target = json['target'] is Map
        ? ElementTarget.fromJson(
            Map<String, dynamic>.from(json['target'] as Map),
          )
        : ElementTarget(testId: json['testId']?.toString());
    switch (type) {
      case 'elementVisible':
        return json['target'] is Map
            ? ElementVisibleAssertion.target(
                target,
                visible: json['visible'] != false,
              )
            : ElementVisibleAssertion(
                testId: json['testId']?.toString() ?? '',
                visible: json['visible'] != false,
              );
      case 'elementText':
        return json['target'] is Map
            ? ElementTextAssertion.target(
                target,
                text: json['text']?.toString() ?? '',
                contains: json['contains'] == true,
              )
            : ElementTextAssertion(
                testId: json['testId']?.toString() ?? '',
                text: json['text']?.toString() ?? '',
                contains: json['contains'] == true,
              );
      case 'screen':
        return ScreenAssertion(screen: json['screen']?.toString() ?? '');
      case 'elementEnabled':
        return json['target'] is Map
            ? ElementEnabledAssertion.target(
                target,
                enabled: json['enabled'] != false,
              )
            : ElementEnabledAssertion(
                testId: json['testId']?.toString() ?? '',
                enabled: json['enabled'] != false,
              );
      case 'elementExists':
        return json['target'] is Map
            ? ElementExistsAssertion.target(
                target,
                exists: json['exists'] != false,
              )
            : ElementExistsAssertion(
                testId: json['testId']?.toString() ?? '',
                exists: json['exists'] != false,
              );
      case 'generic':
        return GenericAssertion(
          domain: json['domain']?.toString() ?? 'ui',
          name: json['name']?.toString() ?? '',
          args: json['args'] is Map
              ? Map<String, dynamic>.from(json['args'] as Map)
              : const {},
        );
      default:
        throw FormatException('Unknown TestAssertion type: $type');
    }
  }
}

class ElementVisibleAssertion extends TestAssertion {
  final String testId;
  final ElementTarget? elementTarget;
  ElementTarget get target => elementTarget ?? ElementTarget(testId: testId);
  final bool visible;
  const ElementVisibleAssertion({required this.testId, this.visible = true})
      : elementTarget = null;
  const ElementVisibleAssertion.target(
    this.elementTarget, {
    this.visible = true,
  }) : testId = '';
  @override
  String get type => 'elementVisible';
  @override
  String get domain => 'ui';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'domain': domain,
        if (target.locator == null) 'testId': testId,
        if (target.locator != null) 'target': target.toJson(),
        'visible': visible,
      };
}

class ElementExistsAssertion extends TestAssertion {
  final String testId;
  final ElementTarget? elementTarget;
  ElementTarget get target => elementTarget ?? ElementTarget(testId: testId);
  final bool exists;
  const ElementExistsAssertion({required this.testId, this.exists = true})
      : elementTarget = null;
  const ElementExistsAssertion.target(
    this.elementTarget, {
    this.exists = true,
  }) : testId = '';
  @override
  String get type => 'elementExists';
  @override
  String get domain => 'ui';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'domain': domain,
        if (target.locator == null) 'testId': testId,
        if (target.locator != null) 'target': target.toJson(),
        'exists': exists,
      };
}

class ElementTextAssertion extends TestAssertion {
  final String testId;
  final ElementTarget? elementTarget;
  ElementTarget get target => elementTarget ?? ElementTarget(testId: testId);
  final String text;
  final bool contains;
  const ElementTextAssertion({
    required this.testId,
    required this.text,
    this.contains = false,
  }) : elementTarget = null;
  const ElementTextAssertion.target(
    this.elementTarget, {
    required this.text,
    this.contains = false,
  }) : testId = '';
  @override
  String get type => 'elementText';
  @override
  String get domain => 'ui';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'domain': domain,
        if (target.locator == null) 'testId': testId,
        if (target.locator != null) 'target': target.toJson(),
        'text': text,
        'contains': contains,
      };
}

class ElementEnabledAssertion extends TestAssertion {
  final String testId;
  final ElementTarget? elementTarget;
  ElementTarget get target => elementTarget ?? ElementTarget(testId: testId);
  final bool enabled;
  const ElementEnabledAssertion({required this.testId, this.enabled = true})
      : elementTarget = null;
  const ElementEnabledAssertion.target(
    this.elementTarget, {
    this.enabled = true,
  }) : testId = '';
  @override
  String get type => 'elementEnabled';
  @override
  String get domain => 'ui';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'domain': domain,
        if (target.locator == null) 'testId': testId,
        if (target.locator != null) 'target': target.toJson(),
        'enabled': enabled,
      };
}

class ScreenAssertion extends TestAssertion {
  final String screen;
  const ScreenAssertion({required this.screen});
  @override
  String get type => 'screen';
  @override
  String get domain => 'navigation';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'domain': domain,
        'screen': screen,
      };
}

/// Escape hatch for YAML expect* steps not yet given a dedicated type.
class GenericAssertion extends TestAssertion {
  @override
  final String domain;
  final String name;
  final Map<String, dynamic> args;
  const GenericAssertion({
    required this.domain,
    required this.name,
    this.args = const {},
  });
  @override
  String get type => 'generic';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'domain': domain,
        'name': name,
        'args': args,
      };
}

enum AssertionStatus { passed, failed, error }

class AssertionResult {
  final String assertionId;
  final AssertionStatus status;
  final String? message;
  final TestExecutionError? error;

  const AssertionResult({
    required this.assertionId,
    required this.status,
    this.message,
    this.error,
  });

  bool get passed => status == AssertionStatus.passed;

  Map<String, dynamic> toJson() => {
        'assertionId': assertionId,
        'status': status.name,
        if (message != null) 'message': message,
        if (error != null) 'error': error!.toJson(),
      };

  factory AssertionResult.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString() ?? 'failed';
    final status = AssertionStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => AssertionStatus.failed,
    );
    final errorRaw = json['error'];
    return AssertionResult(
      assertionId: json['assertionId']?.toString() ?? '',
      status: status,
      message: json['message']?.toString(),
      error: errorRaw is Map
          ? TestExecutionError.fromJson(Map<String, dynamic>.from(errorRaw))
          : null,
    );
  }
}

/// Condition for [TestExecutionSession.waitFor].
sealed class WaitCondition {
  const WaitCondition();

  String get type;
  String get waitKind;

  Map<String, dynamic> toJson();

  static WaitCondition fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    switch (type) {
      case 'pump':
        return PumpWait(
          duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
        );
      case 'settle':
        return SettleWait(
          timeout: json['timeoutMs'] is int
              ? Duration(milliseconds: json['timeoutMs'] as int)
              : null,
        );
      case 'element':
        return json['target'] is Map
            ? ElementWait.target(
                ElementTarget.fromJson(
                  Map<String, dynamic>.from(json['target'] as Map),
                ),
                gone: json['gone'] == true,
              )
            : ElementWait(
                testId: json['testId']?.toString() ?? '',
                gone: json['gone'] == true,
              );
      case 'text':
        return TextWait(
          text: json['text']?.toString(),
          anyOf: (json['anyOf'] as List?)?.map((e) => e.toString()).toList(),
        );
      case 'screen':
        return ScreenWait(screen: json['screen']?.toString() ?? '');
      case 'api':
        return ApiWait(
          name: json['name']?.toString(),
          args: json['args'] is Map
              ? Map<String, dynamic>.from(json['args'] as Map)
              : const {},
        );
      case 'generic':
        return GenericWait(
          name: json['name']?.toString() ?? '',
          waitKind: json['waitKind']?.toString() ?? 'uiElement',
          args: json['args'] is Map
              ? Map<String, dynamic>.from(json['args'] as Map)
              : const {},
        );
      default:
        throw FormatException('Unknown WaitCondition type: $type');
    }
  }
}

class PumpWait extends WaitCondition {
  final Duration duration;
  const PumpWait({this.duration = Duration.zero});
  @override
  String get type => 'pump';
  @override
  String get waitKind => 'pump';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'durationMs': duration.inMilliseconds,
      };
}

class SettleWait extends WaitCondition {
  final Duration? timeout;
  const SettleWait({this.timeout});
  @override
  String get type => 'settle';
  @override
  String get waitKind => 'settle';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (timeout != null) 'timeoutMs': timeout!.inMilliseconds,
      };
}

class ElementWait extends WaitCondition {
  final String testId;
  final ElementTarget? elementTarget;
  ElementTarget get target => elementTarget ?? ElementTarget(testId: testId);
  final bool gone;
  const ElementWait({required this.testId, this.gone = false})
      : elementTarget = null;
  const ElementWait.target(this.elementTarget, {this.gone = false})
      : testId = '';
  @override
  String get type => 'element';
  @override
  String get waitKind => 'uiElement';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (target.locator == null) 'testId': testId,
        if (target.locator != null) 'target': target.toJson(),
        'gone': gone,
      };
}

class TextWait extends WaitCondition {
  final String? text;
  final List<String>? anyOf;
  const TextWait({this.text, this.anyOf});
  @override
  String get type => 'text';
  @override
  String get waitKind => 'text';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (text != null) 'text': text,
        if (anyOf != null) 'anyOf': anyOf,
      };
}

class ScreenWait extends WaitCondition {
  final String screen;
  const ScreenWait({required this.screen});
  @override
  String get type => 'screen';
  @override
  String get waitKind => 'navigation';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'screen': screen};
}

class ApiWait extends WaitCondition {
  final String? name;
  final Map<String, dynamic> args;
  const ApiWait({this.name, this.args = const {}});
  @override
  String get type => 'api';
  @override
  String get waitKind => 'api';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (name != null) 'name': name,
        'args': args,
      };
}

/// Escape hatch for registry waits without a dedicated sealed subtype.
class GenericWait extends WaitCondition {
  final String name;
  @override
  final String waitKind;
  final Map<String, dynamic> args;
  const GenericWait({
    required this.name,
    this.waitKind = 'uiElement',
    this.args = const {},
  });
  @override
  String get type => 'generic';
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'name': name,
        'waitKind': waitKind,
        'args': args,
      };
}

enum WaitStatus { satisfied, timedOut, cancelled, failed }

class WaitResult {
  final String waitId;
  final WaitStatus status;
  final Duration duration;
  final TestExecutionError? error;

  const WaitResult({
    required this.waitId,
    required this.status,
    required this.duration,
    this.error,
  });

  bool get satisfied => status == WaitStatus.satisfied;

  Map<String, dynamic> toJson() => {
        'waitId': waitId,
        'status': status.name,
        'durationMs': duration.inMilliseconds,
        if (error != null) 'error': error!.toJson(),
      };

  factory WaitResult.fromJson(Map<String, dynamic> json) {
    final statusName = json['status']?.toString() ?? 'failed';
    final status = WaitStatus.values.firstWhere(
      (s) => s.name == statusName,
      orElse: () => WaitStatus.failed,
    );
    final errorRaw = json['error'];
    return WaitResult(
      waitId: json['waitId']?.toString() ?? '',
      status: status,
      duration: Duration(milliseconds: json['durationMs'] as int? ?? 0),
      error: errorRaw is Map
          ? TestExecutionError.fromJson(Map<String, dynamic>.from(errorRaw))
          : null,
    );
  }
}
