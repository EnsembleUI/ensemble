/// How to address a rendered element for [TestAction]s.
///
/// When [elementId] is set, [observationId] is required and resolution uses the
/// observation registry only — never falls back to [testId].
class ElementLocator {
  final String? id;
  final String? text;
  final String? label;
  final String? role;
  final ElementLocator? within;
  final int? occurrence;

  const ElementLocator({
    this.id,
    this.text,
    this.label,
    this.role,
    this.within,
    this.occurrence,
  });

  bool get isEmpty =>
      id == null && text == null && label == null && role == null;

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (text != null) 'text': text,
        if (label != null) 'label': label,
        if (role != null) 'role': role,
        if (within != null) 'within': within!.toJson(),
        if (occurrence != null) 'occurrence': occurrence,
      };

  factory ElementLocator.fromJson(Map<String, dynamic> json) => ElementLocator(
        id: json['id']?.toString(),
        text: json['text']?.toString(),
        label: json['label']?.toString(),
        role: json['role']?.toString(),
        within: json['within'] is Map
            ? ElementLocator.fromJson(
                Map<String, dynamic>.from(json['within'] as Map),
              )
            : null,
        occurrence: json['occurrence'] as int?,
      );
}

class ElementTarget {
  final String? testId;
  final String? elementId;
  final String? observationId;
  final int? occurrence;
  final ElementLocator? locator;

  const ElementTarget({
    this.testId,
    this.elementId,
    this.observationId,
    this.occurrence,
    this.locator,
  });

  bool get usesSnapshotElement => elementId != null && elementId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        if (testId != null) 'testId': testId,
        if (elementId != null) 'elementId': elementId,
        if (observationId != null) 'observationId': observationId,
        if (occurrence != null) 'occurrence': occurrence,
        if (locator != null) 'locator': locator!.toJson(),
      };

  factory ElementTarget.fromJson(Map<String, dynamic> json) => ElementTarget(
        testId: json['testId']?.toString(),
        elementId: json['elementId']?.toString(),
        observationId: json['observationId']?.toString(),
        occurrence: json['occurrence'] as int?,
        locator: json['locator'] is Map
            ? ElementLocator.fromJson(
                Map<String, dynamic>.from(json['locator'] as Map),
              )
            : null,
      );

  ElementLocator? get normalizedLocator {
    if (locator != null) return locator;
    if (testId == null || testId!.isEmpty) return null;
    return ElementLocator(id: testId, occurrence: occurrence);
  }
}

enum SwipeDirection { up, down, left, right }

enum ActionStatus { succeeded, failed, timedOut, cancelled }

/// Typed, YAML-independent UI action.
sealed class TestAction {
  const TestAction();

  String get type;

  /// Primary UI target when the action addresses an element; null otherwise.
  ///
  /// Keeps session expected-observation checks from enumerating every subtype.
  ElementTarget? get primaryTarget => null;

  Map<String, dynamic> toJson();

  static TestAction fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? '';
    final targetRaw = json['target'];
    final target = targetRaw is Map
        ? ElementTarget.fromJson(Map<String, dynamic>.from(targetRaw))
        : const ElementTarget();
    switch (type) {
      case 'tap':
        return TapAction(target);
      case 'doubleTap':
        return DoubleTapAction(target);
      case 'longPress':
        return LongPressAction(target);
      case 'enterText':
        return EnterTextAction(
          target: target,
          value: json['value']?.toString() ?? '',
        );
      case 'clearText':
        return ClearTextAction(target);
      case 'replaceText':
        return ReplaceTextAction(
          target: target,
          value: json['value']?.toString() ?? '',
        );
      case 'submitText':
        return SubmitTextAction(target);
      case 'focus':
        return FocusAction(target);
      case 'unfocus':
        return UnfocusAction(target);
      case 'select':
        return SelectAction(
          target: target,
          value: json['value']?.toString() ?? '',
        );
      case 'selectIndex':
        return SelectIndexAction(
          target: target,
          index: json['index'] as int? ?? 0,
        );
      case 'check':
        return CheckAction(target);
      case 'uncheck':
        return UncheckAction(target);
      case 'toggle':
        return ToggleAction(target);
      case 'setSlider':
        return SetSliderAction(
          target: target,
          value: (json['value'] as num?)?.toDouble() ?? 0,
        );
      case 'scroll':
        return ScrollAction(
          target: targetRaw is Map ? target : null,
          direction: _directionFrom(json['direction']),
          distance: (json['distance'] as num?)?.toDouble(),
        );
      case 'scrollUntilVisible':
        return ScrollUntilVisibleAction(
          target: target,
          scrollableId: json['scrollableId']?.toString(),
        );
      case 'swipe':
        return SwipeAction(
          direction: _directionFrom(json['direction']),
          target: targetRaw is Map ? target : null,
        );
      case 'drag':
        return DragAction(
          target: target,
          dx: (json['dx'] as num?)?.toDouble() ?? 0,
          dy: (json['dy'] as num?)?.toDouble() ?? 0,
        );
      case 'pullToRefresh':
        return PullToRefreshAction(
          target: targetRaw is Map ? target : null,
        );
      case 'chooseDate':
        return ChooseDateAction(
          target: target,
          value: json['value']?.toString() ?? '',
        );
      case 'chooseTime':
        return ChooseTimeAction(
          target: target,
          value: json['value']?.toString() ?? '',
        );
      case 'generic':
        return GenericAction(
          name: json['name']?.toString() ?? '',
          args: json['args'] is Map
              ? Map<String, dynamic>.from(json['args'] as Map)
              : const {},
        );
      default:
        throw FormatException('Unknown TestAction type: $type');
    }
  }

  static SwipeDirection _directionFrom(dynamic raw) {
    final name = raw?.toString() ?? 'down';
    return SwipeDirection.values.firstWhere(
      (d) => d.name == name,
      orElse: () => SwipeDirection.down,
    );
  }
}

class TapAction extends TestAction {
  final ElementTarget target;
  final int? timeoutMs;
  const TapAction(this.target, {this.timeoutMs});
  @override
  String get type => 'tap';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
      };
}

class DoubleTapAction extends TestAction {
  final ElementTarget target;
  final int? timeoutMs;
  const DoubleTapAction(this.target, {this.timeoutMs});
  @override
  String get type => 'doubleTap';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
      };
}

class LongPressAction extends TestAction {
  final ElementTarget target;
  final int? timeoutMs;
  const LongPressAction(this.target, {this.timeoutMs});
  @override
  String get type => 'longPress';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        if (timeoutMs != null) 'timeoutMs': timeoutMs,
      };
}

class EnterTextAction extends TestAction {
  final ElementTarget target;
  final String value;
  const EnterTextAction({required this.target, required this.value});
  @override
  String get type => 'enterText';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'value': value,
      };
}

class ClearTextAction extends TestAction {
  final ElementTarget target;
  const ClearTextAction(this.target);
  @override
  String get type => 'clearText';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {'type': type, 'target': target.toJson()};
}

class ReplaceTextAction extends TestAction {
  final ElementTarget target;
  final String value;
  const ReplaceTextAction({required this.target, required this.value});
  @override
  String get type => 'replaceText';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'value': value,
      };
}

class SubmitTextAction extends TestAction {
  final ElementTarget target;
  const SubmitTextAction(this.target);
  @override
  String get type => 'submitText';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {'type': type, 'target': target.toJson()};
}

class FocusAction extends TestAction {
  final ElementTarget target;
  const FocusAction(this.target);
  @override
  String get type => 'focus';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {'type': type, 'target': target.toJson()};
}

class UnfocusAction extends TestAction {
  final ElementTarget target;
  const UnfocusAction(this.target);
  @override
  String get type => 'unfocus';
  @override
  Map<String, dynamic> toJson() => {'type': type, 'target': target.toJson()};
}

class SelectAction extends TestAction {
  final ElementTarget target;
  final String value;
  const SelectAction({required this.target, required this.value});
  @override
  String get type => 'select';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'value': value,
      };
}

class SelectIndexAction extends TestAction {
  final ElementTarget target;
  final int index;
  const SelectIndexAction({required this.target, required this.index});
  @override
  String get type => 'selectIndex';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'index': index,
      };
}

class CheckAction extends TestAction {
  final ElementTarget target;
  const CheckAction(this.target);
  @override
  String get type => 'check';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {'type': type, 'target': target.toJson()};
}

class UncheckAction extends TestAction {
  final ElementTarget target;
  const UncheckAction(this.target);
  @override
  String get type => 'uncheck';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {'type': type, 'target': target.toJson()};
}

class ToggleAction extends TestAction {
  final ElementTarget target;
  const ToggleAction(this.target);
  @override
  String get type => 'toggle';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {'type': type, 'target': target.toJson()};
}

class SetSliderAction extends TestAction {
  final ElementTarget target;
  final double value;
  const SetSliderAction({required this.target, required this.value});
  @override
  String get type => 'setSlider';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'value': value,
      };
}

class ScrollAction extends TestAction {
  final ElementTarget? target;
  final SwipeDirection direction;
  final double? distance;
  const ScrollAction({
    this.target,
    this.direction = SwipeDirection.down,
    this.distance,
  });
  @override
  String get type => 'scroll';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (target != null) 'target': target!.toJson(),
        'direction': direction.name,
        if (distance != null) 'distance': distance,
      };
}

class ScrollUntilVisibleAction extends TestAction {
  final ElementTarget target;
  final String? scrollableId;
  const ScrollUntilVisibleAction({required this.target, this.scrollableId});
  @override
  String get type => 'scrollUntilVisible';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        if (scrollableId != null) 'scrollableId': scrollableId,
      };
}

class SwipeAction extends TestAction {
  final SwipeDirection direction;
  final ElementTarget? target;
  const SwipeAction({required this.direction, this.target});
  @override
  String get type => 'swipe';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'direction': direction.name,
        if (target != null) 'target': target!.toJson(),
      };
}

class DragAction extends TestAction {
  final ElementTarget target;
  final double dx;
  final double dy;
  const DragAction({required this.target, required this.dx, required this.dy});
  @override
  String get type => 'drag';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'dx': dx,
        'dy': dy,
      };
}

class PullToRefreshAction extends TestAction {
  final ElementTarget? target;
  const PullToRefreshAction({this.target});
  @override
  String get type => 'pullToRefresh';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        if (target != null) 'target': target!.toJson(),
      };
}

class ChooseDateAction extends TestAction {
  final ElementTarget target;
  final String value;
  const ChooseDateAction({required this.target, required this.value});
  @override
  String get type => 'chooseDate';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'value': value,
      };
}

class ChooseTimeAction extends TestAction {
  final ElementTarget target;
  final String value;
  const ChooseTimeAction({required this.target, required this.value});
  @override
  String get type => 'chooseTime';
  @override
  ElementTarget? get primaryTarget => target;
  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'target': target.toJson(),
        'value': value,
      };
}

/// Escape hatch for registry UI actions without a dedicated sealed subtype.
///
/// Prefer typed actions when the session API is first-class; use this to route
/// new YAML vocabulary steps through [TestStepExecutor] without sealed churn.
class GenericAction extends TestAction {
  final String name;
  final Map<String, dynamic> args;
  const GenericAction({required this.name, this.args = const {}});
  @override
  String get type => name;
  @override
  Map<String, dynamic> toJson() => {
        'type': 'generic',
        'name': name,
        'args': args,
      };
}
