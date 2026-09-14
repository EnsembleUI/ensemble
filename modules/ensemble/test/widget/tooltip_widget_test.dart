import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/util/ensemble_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/tooltip_composite.dart';
import 'package:ensemble/widget/helpers/tv_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

import 'test_utils.dart';

/// Records the `event.data.isOpen` value each time an `onTriggered` action runs.
class _RecordingTriggerAction extends EnsembleAction {
  _RecordingTriggerAction(this.states, {this.onOpen});

  final List<dynamic> states;

  /// Invoked with the scope when the tooltip reports that it opened, used to
  /// simulate a definition storing a one-time flag.
  final void Function(ScopeManager scopeManager)? onOpen;

  @override
  Future<dynamic> execute(BuildContext context, ScopeManager scopeManager) {
    final event = scopeManager.dataContext.getContextById('event');
    if (event is EnsembleEvent && event.data is Map) {
      final isOpen = (event.data as Map)['isOpen'];
      states.add(isOpen);
      if (isOpen == true) onOpen?.call(scopeManager);
    }
    return Future.value(null);
  }
}

FocusNode tooltipScope(WidgetTester tester) => tester
    .widgetList<TVFocusScope>(find.byType(TVFocusScope))
    .singleWhere(
      (scope) => scope.focusNode?.debugLabel == 'TVTooltipScope',
    )
    .focusNode!;

KeyDownEvent _keyDown(LogicalKeyboardKey key) => KeyDownEvent(
      logicalKey: key,
      physicalKey: PhysicalKeyboardKey.arrowDown,
      timeStamp: Duration.zero,
    );

/// Two focusable declarative children used to exercise in-tooltip traversal.
final YamlMap twoButtonWidget = loadYaml('''
Column:
  styles:
    gap: 8
  children:
    - Button:
        label: First
    - Button:
        label: Second
''');

/// Pumps a centered [TVTooltip] with a 40x40 anchor and opens it.
///
/// Returns the anchor's rect. The anchor is centered in the 800x600 test
/// window, so its top-left is always (380, 280).
Future<Rect> pumpAndOpenTooltip(
  WidgetTester tester, {
  required FocusNode anchorFocus,
  required GlobalKey anchorKey,
  TooltipOptions options = const TooltipOptions(),
  dynamic widget,
}) async {
  await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
    Center(
      child: TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: widget ??
              {
                'Button': {'label': 'Add favorites'}
              },
          options: options,
        ),
        child: Focus(
          focusNode: anchorFocus,
          child: SizedBox(key: anchorKey, width: 40, height: 40),
        ),
      ),
    ),
  ));

  anchorFocus.requestFocus();
  await tester.pump();
  await tester.pump();
  return tester.getRect(find.byKey(anchorKey));
}

class _PlacementSpec {
  const _PlacementSpec(
    this.position,
    this.alignment,
    this.anchorPoint,
    this.tooltipPoint,
  );

  final TooltipPosition position;
  final TooltipAlignment alignment;
  final Offset Function(Rect) anchorPoint;
  final Offset Function(Rect) tooltipPoint;
}

final List<_PlacementSpec> _placementSpecs = [
  _PlacementSpec(TooltipPosition.below, TooltipAlignment.start,
      (r) => r.bottomLeft, (r) => r.topLeft),
  _PlacementSpec(TooltipPosition.below, TooltipAlignment.center,
      (r) => r.bottomCenter, (r) => r.topCenter),
  _PlacementSpec(TooltipPosition.below, TooltipAlignment.end,
      (r) => r.bottomRight, (r) => r.topRight),
  _PlacementSpec(TooltipPosition.above, TooltipAlignment.start,
      (r) => r.topLeft, (r) => r.bottomLeft),
  _PlacementSpec(TooltipPosition.above, TooltipAlignment.center,
      (r) => r.topCenter, (r) => r.bottomCenter),
  _PlacementSpec(TooltipPosition.above, TooltipAlignment.end,
      (r) => r.topRight, (r) => r.bottomRight),
  _PlacementSpec(TooltipPosition.left, TooltipAlignment.start,
      (r) => r.topLeft, (r) => r.topRight),
  _PlacementSpec(TooltipPosition.left, TooltipAlignment.center,
      (r) => r.centerLeft, (r) => r.centerRight),
  _PlacementSpec(TooltipPosition.left, TooltipAlignment.end,
      (r) => r.bottomLeft, (r) => r.bottomRight),
  _PlacementSpec(TooltipPosition.right, TooltipAlignment.start,
      (r) => r.topRight, (r) => r.topLeft),
  _PlacementSpec(TooltipPosition.right, TooltipAlignment.center,
      (r) => r.centerRight, (r) => r.centerLeft),
  _PlacementSpec(TooltipPosition.right, TooltipAlignment.end,
      (r) => r.bottomRight, (r) => r.bottomLeft),
];

void main() {
  test('tooltip options parse supported values', () {
    final tooltip = TooltipData.from({
      'options': {
        'enabled': false,
        'position': 'right',
        'alignment': 'end',
        'offset': '12 -4',
        'dismissOnFocusLoss': false,
        'dismissOnBack': false,
        'restoreFocus': false,
        'animation': {
          'type': 'slide',
          'duration': 150,
          'curve': 'easeInOut',
        },
      },
    }, ChangeNotifier())!;

    expect(tooltip.options.enabled, isFalse);
    expect(tooltip.options.position, TooltipPosition.right);
    expect(tooltip.options.alignment, TooltipAlignment.end);
    expect(tooltip.options.offset, const Offset(12, -4));
    expect(tooltip.options.dismissOnFocusLoss, isFalse);
    expect(tooltip.options.dismissOnBack, isFalse);
    expect(tooltip.options.restoreFocus, isFalse);
    expect(tooltip.options.animation.type, TooltipAnimationType.slide);
    expect(
        tooltip.options.animation.duration, const Duration(milliseconds: 150));
    expect(tooltip.options.animation.curve, Curves.easeInOut);
  });

  test('tooltip is enabled by default', () {
    final tooltip = TooltipData.from({'widget': {}}, ChangeNotifier())!;
    expect(tooltip.options.enabled, isTrue);
  });

  testWidgets('message tooltip continues to use Flutter Tooltip',
      (tester) async {
    await tester.pumpWidget(TestUtils.wrapTestWidget(Builder(
      builder: (context) => Utils.getTooltipWidget(
        context,
        const Text('anchor'),
        const {'message': 'Existing help'},
        ChangeNotifier(),
      ),
    )));

    expect(find.byType(Tooltip), findsOneWidget);
    expect(find.text('anchor'), findsOneWidget);
  });

  testWidgets('TV tooltip opens declarative content on anchor focus',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(find.text('Add favorites'), findsOneWidget);
    // Real focus is inside the tooltip, but the anchor stays in the focus chain
    // (shallow focus) so its `${id.hasFocus}` styling remains applied.
    expect(anchorFocus.hasPrimaryFocus, isFalse);
    expect(anchorFocus.hasFocus, isTrue);
    expect(
      FocusManager.instance.primaryFocus!.ancestors.contains(anchorFocus),
      isTrue,
    );
  });

  testWidgets('TV tooltip does not open when the anchor scope itself has focus',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    final anchorScope = tester
        .widgetList<FocusScope>(find.byType(FocusScope))
        .firstWhere(
          (scope) =>
              scope.focusNode?.debugLabel == 'TVTooltipAnchorScope',
        )
        .focusNode!;
    // Flutter can land focus on the scope node when a focused descendant is
    // removed; that must not be mistaken for the anchor control being focused.
    anchorScope.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(find.text('Add favorites'), findsNothing);
  });

  testWidgets('TV tooltip does not open while disabled', (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
          options: const TooltipOptions(enabled: false),
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(find.text('Add favorites'), findsNothing);
  });

  testWidgets('TV tooltip enabled supports a binding expression',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
          options: const TooltipOptions(enabled: r'${showTooltip}'),
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    final scopeManager = DataScopeWidget.getScope(
      tester.element(find.byType(TVTooltip)),
    )!;
    scopeManager.dataContext.addToThisContext('showTooltip', false);

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsNothing);

    // The condition is read when the trigger fires, so flipping it and
    // re-focusing opens the tooltip without rebuilding the widget.
    scopeManager.dataContext.addToThisContext('showTooltip', true);
    anchorFocus.unfocus();
    await tester.pump();
    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsOneWidget);
  });

  testWidgets('TV tooltip one-time gate set on open stays open but blocks reopen',
      (tester) async {
    final anchorFocus = FocusNode();
    final states = <dynamic>[];
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
          options: const TooltipOptions(enabled: r'${!seen}'),
          onTriggered: _RecordingTriggerAction(
            states,
            onOpen: (scopeManager) =>
                scopeManager.dataContext.addToThisContext('seen', true),
          ),
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    // The open handler marks it seen; the gate is now false but the tooltip
    // must stay open until the user dismisses it.
    expect(find.text('Add favorites'), findsOneWidget);
    expect(states, [true]);

    await EnsembleUtils.dismissTooltip(
      tester.element(find.byType(TVTooltip)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsNothing);
    expect(states, [true, false]);

    // Re-focusing no longer opens it (show only once).
    anchorFocus.unfocus();
    await tester.pump();
    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsNothing);
  });

  testWidgets('TV tooltip onTriggered reports open and close state',
      (tester) async {
    final anchorFocus = FocusNode();
    final states = <dynamic>[];
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
          onTriggered: _RecordingTriggerAction(states),
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(states, [true]);
    expect(find.text('Add favorites'), findsOneWidget);

    await EnsembleUtils.dismissTooltip(
      tester.element(find.byType(TVTooltip)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(states, [true, false]);
    expect(find.text('Add favorites'), findsNothing);
  });

  testWidgets('TV tooltip content is intrinsically sized in the overlay',
      (tester) async {
    final anchorFocus = FocusNode();
    final anchorKey = GlobalKey();
    addTearDown(anchorFocus.dispose);

    await pumpAndOpenTooltip(
      tester,
      anchorFocus: anchorFocus,
      anchorKey: anchorKey,
    );

    // The overlay child is laid out with the Overlay's tight constraints; the
    // tooltip must not be stretched to the full 800x600 test window.
    final tooltipRect = tester.getRect(find.byType(FilledButton));
    expect(tooltipRect.width, lessThan(700));
    expect(tooltipRect.height, lessThan(500));
  });

  testWidgets('TV tooltip aligns to the anchor for every placement',
      (tester) async {
    for (final spec in _placementSpecs) {
      final anchorFocus = FocusNode();
      final anchorKey = GlobalKey();
      addTearDown(anchorFocus.dispose);

      final anchorRect = await pumpAndOpenTooltip(
        tester,
        anchorFocus: anchorFocus,
        anchorKey: anchorKey,
        options: TooltipOptions(
          position: spec.position,
          alignment: spec.alignment,
        ),
      );
      final tooltipRect = tester.getRect(find.byType(FilledButton));

      expect(
        spec.tooltipPoint(tooltipRect),
        spec.anchorPoint(anchorRect),
        reason: '${spec.position}/${spec.alignment}',
      );
    }
  });

  testWidgets('TV tooltip applies the configured offset', (tester) async {
    final anchorFocus = FocusNode();
    final anchorKey = GlobalKey();
    addTearDown(anchorFocus.dispose);

    const offset = Offset(12, -4);
    final anchorRect = await pumpAndOpenTooltip(
      tester,
      anchorFocus: anchorFocus,
      anchorKey: anchorKey,
      options: const TooltipOptions(
        position: TooltipPosition.right,
        alignment: TooltipAlignment.center,
        offset: offset,
      ),
    );
    final tooltipRect = tester.getRect(find.byType(FilledButton));

    expect(tooltipRect.centerLeft, anchorRect.centerRight + offset);
  });

  testWidgets('TV tooltip applies the configured animation', (tester) async {
    final anchorFocus = FocusNode();
    final anchorKey = GlobalKey();
    addTearDown(anchorFocus.dispose);

    await pumpAndOpenTooltip(
      tester,
      anchorFocus: anchorFocus,
      anchorKey: anchorKey,
      options: const TooltipOptions(
        animation: TooltipAnimation(
          type: TooltipAnimationType.fade,
          duration: Duration(milliseconds: 150),
        ),
      ),
    );

    expect(find.byType(FadeTransition), findsWidgets);
    expect(find.text('Add favorites'), findsOneWidget);
  });

  testWidgets('Back dismisses TV tooltip and restores anchor focus',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    final scope = tooltipScope(tester);
    final result = scope.onKeyEvent!(
      scope,
      const KeyDownEvent(
        logicalKey: LogicalKeyboardKey.goBack,
        physicalKey: PhysicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
    );
    expect(result, KeyEventResult.handled);
    // Allow the post-frame focus restoration to settle and verify the tooltip
    // does not immediately reopen from that programmatic focus change.
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(find.text('Add favorites'), findsNothing);
    expect(anchorFocus.hasFocus, isTrue);
  });

  testWidgets('TV tooltip traverses focus inside the tooltip', (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      Center(
        child: TVTooltip(
          tooltip: TooltipData(message: '', widget: twoButtonWidget),
          child: Focus(
            focusNode: anchorFocus,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    final scope = tooltipScope(tester);
    final first = FocusManager.instance.primaryFocus;
    expect(first, isNotNull);

    final result = scope.onKeyEvent!(
      scope,
      _keyDown(LogicalKeyboardKey.arrowDown),
    );
    await tester.pump();

    expect(result, KeyEventResult.handled);
    expect(FocusManager.instance.primaryFocus, isNot(first));
    // Still open: focus only moved between the tooltip's children.
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('TV tooltip contains focus at the D-pad edge', (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      Center(
        child: TVTooltip(
          tooltip: TooltipData(message: '', widget: twoButtonWidget),
          child: Focus(
            focusNode: anchorFocus,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    final scope = tooltipScope(tester);
    // Move down to the last child.
    scope.onKeyEvent!(scope, _keyDown(LogicalKeyboardKey.arrowDown));
    await tester.pump();
    expect(find.text('First'), findsOneWidget);

    // Another down at the edge must keep focus inside the tooltip rather than
    // dismiss it or hand focus back to the anchor.
    final result = scope.onKeyEvent!(
      scope,
      _keyDown(LogicalKeyboardKey.arrowDown),
    );
    await tester.pump();
    await tester.pump();

    expect(result, KeyEventResult.handled);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
    expect(anchorFocus.hasFocus, isTrue);
    expect(anchorFocus.hasPrimaryFocus, isFalse);
  });

  for (final (label, key) in [
    ('up', LogicalKeyboardKey.arrowUp),
    ('down', LogicalKeyboardKey.arrowDown),
    ('left', LogicalKeyboardKey.arrowLeft),
    ('right', LogicalKeyboardKey.arrowRight),
  ]) {
    testWidgets('TV tooltip keeps focus on $label at the tooltip edge',
        (tester) async {
      final anchorFocus = FocusNode();
      final anchorKey = GlobalKey();
      addTearDown(anchorFocus.dispose);

      await pumpAndOpenTooltip(
        tester,
        anchorFocus: anchorFocus,
        anchorKey: anchorKey,
      );

      final scope = tooltipScope(tester);
      final result = scope.onKeyEvent!(scope, _keyDown(key));
      await tester.pump();
      await tester.pump();

      expect(result, KeyEventResult.handled);
      expect(find.text('Add favorites'), findsOneWidget);
      expect(anchorFocus.hasFocus, isTrue);
      expect(anchorFocus.hasPrimaryFocus, isFalse);
    });
  }

  testWidgets(
      'TV tooltip stays open on D-pad edge when dismissOnFocusLoss is false',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      Center(
        child: TVTooltip(
          tooltip: TooltipData(
            message: '',
            widget: twoButtonWidget,
            options: const TooltipOptions(dismissOnFocusLoss: false),
          ),
          child: Focus(
            focusNode: anchorFocus,
            child: const SizedBox(width: 40, height: 40),
          ),
        ),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    final scope = tooltipScope(tester);
    // First down moves to the second child, second down is at the edge.
    scope.onKeyEvent!(scope, _keyDown(LogicalKeyboardKey.arrowDown));
    await tester.pump();
    final result = scope.onKeyEvent!(
      scope,
      _keyDown(LogicalKeyboardKey.arrowDown),
    );
    await tester.pump();
    await tester.pump();

    expect(result, KeyEventResult.handled);
    expect(find.text('First'), findsOneWidget);
    expect(find.text('Second'), findsOneWidget);
  });

  testWidgets('TV tooltip leaves Back unhandled when dismissal is disabled',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
          options: const TooltipOptions(dismissOnBack: false),
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    final scope = tooltipScope(tester);
    final result = scope.onKeyEvent!(
      scope,
      const KeyDownEvent(
        logicalKey: LogicalKeyboardKey.goBack,
        physicalKey: PhysicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
    );

    expect(result, KeyEventResult.ignored);
    expect(find.text('Add favorites'), findsOneWidget);
  });

  testWidgets('TV tooltip closes when focus leaves its scope', (tester) async {
    final anchorFocus = FocusNode();
    final outsideFocus = FocusNode();
    addTearDown(anchorFocus.dispose);
    addTearDown(outsideFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(Row(
      children: [
        TVTooltip(
          tooltip: TooltipData(
            message: '',
            widget: {
              'Button': {'label': 'Add favorites'}
            },
          ),
          child:
              Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
        ),
        Focus(focusNode: outsideFocus, child: const SizedBox(width: 20)),
      ],
    )));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    outsideFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(outsideFocus.hasFocus, isTrue);
    expect(find.text('Add favorites'), findsNothing);
  });

  testWidgets('TV tooltip reopens when focus leaves and returns',
      (tester) async {
    final anchorFocus = FocusNode();
    final outsideFocus = FocusNode();
    addTearDown(anchorFocus.dispose);
    addTearDown(outsideFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(Row(
      children: [
        TVTooltip(
          tooltip: TooltipData(
            message: '',
            widget: {
              'Button': {'label': 'Add favorites'}
            },
          ),
          child:
              Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
        ),
        Focus(focusNode: outsideFocus, child: const SizedBox(width: 20)),
      ],
    )));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsOneWidget);

    outsideFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsNothing);

    // Returning focus to the anchor is a fresh rising edge and reopens.
    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsOneWidget);
  });

  testWidgets('TV tooltip keeps focus on a real D-pad edge key event',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Button': {'label': 'Add favorites'}
          },
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();
    expect(find.text('Add favorites'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.pump();

    expect(find.text('Add favorites'), findsOneWidget);
    // Real focus is inside the tooltip, but the anchor stays in the focus chain
    // (shallow focus) so its `${id.hasFocus}` styling remains applied.
    expect(anchorFocus.hasPrimaryFocus, isFalse);
    expect(anchorFocus.hasFocus, isTrue);
    expect(
      FocusManager.instance.primaryFocus!.ancestors.contains(anchorFocus),
      isTrue,
    );
  });

  testWidgets('TV tooltip exposes a locking focus scope while open',
      (tester) async {
    final anchorFocus = FocusNode();
    final anchorKey = GlobalKey();
    addTearDown(anchorFocus.dispose);

    await pumpAndOpenTooltip(
      tester,
      anchorFocus: anchorFocus,
      anchorKey: anchorKey,
    );

    final scope = tester.widget<TVFocusScope>(find.byType(TVFocusScope));
    expect(scope.lockScope, isTrue);
    expect(scope.onLeftEdge, isNotNull);
    expect(scope.onRightEdge, isNotNull);
    expect(scope.onTopEdge, isNotNull);
    expect(scope.onBottomEdge, isNotNull);
  });

  testWidgets('dismissTooltip closes the tooltip and restores anchor focus',
      (tester) async {
    final anchorFocus = FocusNode();
    final anchorKey = GlobalKey();
    addTearDown(anchorFocus.dispose);

    await pumpAndOpenTooltip(
      tester,
      anchorFocus: anchorFocus,
      anchorKey: anchorKey,
    );
    expect(find.text('Add favorites'), findsOneWidget);

    // Route-scoped programmatic dismissal, as used by the `dismissTooltip`
    // action and `ensemble.dismissTooltip()`.
    final dismissed = await EnsembleUtils.dismissTooltip(
      tester.element(find.byType(TVTooltip)),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(dismissed, isTrue);
    expect(find.text('Add favorites'), findsNothing);
    expect(anchorFocus.hasFocus, isTrue);
  });

  testWidgets('TV tooltip contains focus when content has no focusables',
      (tester) async {
    final anchorFocus = FocusNode();
    addTearDown(anchorFocus.dispose);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      TVTooltip(
        tooltip: TooltipData(
          message: '',
          widget: {
            'Text': {'text': 'Only text'}
          },
        ),
        child: Focus(focusNode: anchorFocus, child: const SizedBox(width: 20)),
      ),
    ));

    anchorFocus.requestFocus();
    await tester.pump();
    await tester.pump();

    expect(find.text('Only text'), findsOneWidget);
    expect(anchorFocus.hasFocus, isTrue);
    expect(anchorFocus.hasPrimaryFocus, isFalse);
    // Focus falls back to the tooltip scope so D-pad cannot drift to the
    // background while the tooltip is open.
    final scopeNode =
        tester.widget<TVFocusScope>(find.byType(TVFocusScope)).focusNode;
    expect(FocusManager.instance.primaryFocus, scopeNode);
  });
}
