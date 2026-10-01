import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locks in the O(1) traversal-group check added to [TVFocusTarget].
///
/// The target captures its enclosing [FocusTraversalGroup] at registration so
/// navigation never has to walk the ancestor chain per D-pad press.
void main() {
  testWidgets(
    'TVFocusTarget.isInTraversalGroup matches the captured group and rejects others',
    (tester) async {
      final focusNode = FocusNode();
      final groupBKey = GlobalKey();

      late BuildContext capturedContext;
      await tester.pumpWidget(MaterialApp(
        home: FocusTraversalGroup(
          key: groupBKey,
          policy: ReadingOrderTraversalPolicy(),
          child: Builder(builder: (context) {
            capturedContext = context;
            return const SizedBox(key: ValueKey('target'));
          }),
        ),
      ));

      final capturedGroup = groupBKey.currentWidget as FocusTraversalGroup;
      final target = TVFocusTarget(
        focusNode: focusNode,
        focusOrder: const TVFocusOrder(0, 0),
        row: 0,
        order: 0,
        context: capturedContext,
        traversalGroup: capturedContext
            .findAncestorWidgetOfExactType<FocusTraversalGroup>(),
      );

      // Captured group identity matches.
      expect(target.isInTraversalGroup(capturedGroup), isTrue);
      // A different live group is rejected without an ancestor walk.
      expect(
        target.isInTraversalGroup(
          FocusTraversalGroup(policy: ReadingOrderTraversalPolicy(), child: const SizedBox()),
        ),
        isFalse,
      );
      // No group queried => always in scope.
      expect(target.isInTraversalGroup(null), isTrue);

      focusNode.dispose();
    },
  );

  test('TVFocusTarget without a captured group never claims a group', () {
    final target = TVFocusTarget(
      focusNode: FocusNode(),
      focusOrder: const TVFocusOrder(0, 0),
      row: 0,
      order: 0,
      context: _FakeContext(),
    );
    expect(target.isInTraversalGroup(null), isTrue);
    expect(
      target.isInTraversalGroup(
        FocusTraversalGroup(policy: ReadingOrderTraversalPolicy(), child: const SizedBox()),
      ),
      isFalse,
    );
  });
}

/// Minimal BuildContext whose ancestor walk returns null.
class _FakeContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
