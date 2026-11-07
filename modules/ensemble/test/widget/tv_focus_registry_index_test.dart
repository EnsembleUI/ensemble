import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Exercises the route/row/order index that lets TV navigation resolve a
/// neighbour with direct lookups instead of rebuilding the grid from every
/// focus node on each D-pad press.
void main() {
  // The registry is process-global; each test uses a distinct row set and
  // unregisters what it adds so buckets don't leak across tests.
  testWidgets('rowTargets returns the row ordered by order', (tester) async {
    final nodes = <FocusNode>[];
    late BuildContext context;

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) {
        context = ctx;
        return const SizedBox();
      }),
    ));

    // Register out of order to prove the index sorts by order.
    for (final order in [2.0, 0.0, 1.0]) {
      final node = FocusNode();
      nodes.add(node);
      TVFocusRegistry.register(TVFocusTarget(
        focusNode: node,
        focusOrder: TVFocusOrder(10, order),
        row: 10,
        order: order,
        context: context,
      ));
    }
    // Mount the nodes so isRequestable is true.
    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [for (final n in nodes) Focus(focusNode: n, child: const SizedBox())],
      ),
    ));
    await tester.pump();

    final row = TVFocusRegistry.rowTargets(route: null, row: 10);
    expect(row.map((t) => t.order).toList(), [0.0, 1.0, 2.0]);

    for (final n in nodes) {
      TVFocusRegistry.unregister(n);
      n.dispose();
    }
  });

  testWidgets('cellTarget and hasCell resolve an exact coordinate',
      (tester) async {
    final node = FocusNode();
    late BuildContext context;

    await tester.pumpWidget(MaterialApp(
      home: Focus(focusNode: node, child: const SizedBox()),
    ));
    await tester.pump();

    // Grab a context under the Focus so isRequestable sees a mounted node.
    context = tester.element(find.byType(SizedBox).last);

    TVFocusRegistry.register(TVFocusTarget(
      focusNode: node,
      focusOrder: const TVFocusOrder(3, 4),
      row: 3,
      order: 4,
      context: context,
    ));

    expect(TVFocusRegistry.hasCell(route: null, row: 3, order: 4), isTrue);
    expect(TVFocusRegistry.cellTarget(route: null, row: 3, order: 4), isNotNull);
    expect(TVFocusRegistry.hasCell(route: null, row: 3, order: 99), isFalse);

    TVFocusRegistry.unregister(node);
    node.dispose();
  });

  testWidgets('nextRow / previousRow walk rows in order', (tester) async {
    final nodes = <FocusNode>[];
    late BuildContext context;

    await tester.pumpWidget(MaterialApp(
      home: Column(
        children: [
          for (final _ in [0, 1, 2]) Builder(builder: (ctx) {
            final node = FocusNode();
            nodes.add(node);
            context = ctx;
            return Focus(focusNode: node, child: const SizedBox());
          }),
        ],
      ),
    ));
    await tester.pump();

    var i = 0;
    for (final row in [5.0, 7.0, 9.0]) {
      TVFocusRegistry.register(TVFocusTarget(
        focusNode: nodes[i],
        focusOrder: TVFocusOrder(row, 0),
        row: row,
        order: 0,
        context: context,
      ));
      i++;
    }

    expect(TVFocusRegistry.nextRow(route: null, row: 7), 9.0);
    expect(TVFocusRegistry.previousRow(route: null, row: 7), 5.0);
    expect(TVFocusRegistry.nextRow(route: null, row: 9), isNull);
    expect(TVFocusRegistry.previousRow(route: null, row: 5), isNull);

    for (final n in nodes) {
      TVFocusRegistry.unregister(n);
      n.dispose();
    }
  });

  testWidgets('unregister removes the target from the index', (tester) async {
    final node = FocusNode();
    late BuildContext context;

    await tester.pumpWidget(MaterialApp(
      home: Focus(focusNode: node, child: const SizedBox()),
    ));
    await tester.pump();
    context = tester.element(find.byType(SizedBox).last);

    TVFocusRegistry.register(TVFocusTarget(
      focusNode: node,
      focusOrder: const TVFocusOrder(1, 1),
      row: 1,
      order: 1,
      context: context,
    ));
    expect(TVFocusRegistry.hasCell(route: null, row: 1, order: 1), isTrue);

    TVFocusRegistry.unregister(node);
    expect(TVFocusRegistry.hasCell(route: null, row: 1, order: 1), isFalse);

    node.dispose();
  });

  testWidgets(
    'rowValues / rowTargets expose rows above even when only some are built',
    (tester) async {
      // Mirrors the ListView/GridView escape fix: at the top of the BUILT
      // window (row 12), the registry still reports that lower-valued rows
      // exist, so the boundary gate can keep focus inside.
      final nodes = <FocusNode>[];
      late BuildContext context;

      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (ctx) {
          context = ctx;
          return const SizedBox();
        }),
      ));

      for (final row in [1.0, 6.0, 12.0]) {
        final node = FocusNode();
        nodes.add(node);
        TVFocusRegistry.register(TVFocusTarget(
          focusNode: node,
          focusOrder: TVFocusOrder(row, 0),
          row: row,
          order: 0,
          context: context,
          focusGroup: 'list',
        ));
      }
      // Mount the nodes so isRequestable is true.
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            for (final n in nodes) Focus(focusNode: n, child: const SizedBox()),
          ],
        ),
      ));
      await tester.pump();

      // From row 12 there ARE rows above in the data.
      expect(TVFocusRegistry.previousRow(route: null, row: 12), 6.0);
      expect(
        TVFocusRegistry.rowValues(route: null),
        containsAll(<double>[1.0, 6.0, 12.0]),
      );
      // The gate's same-group check finds an eligible row above.
      final above = TVFocusRegistry.rowTargets(route: null, row: 6.0)
          .where((t) => t.focusGroup == 'list');
      expect(above, isNotEmpty);

      for (final n in nodes) {
        TVFocusRegistry.unregister(n);
        n.dispose();
      }
    },
  );
}
