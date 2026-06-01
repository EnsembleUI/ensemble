import 'package:ensemble/layout/helpers/list_view_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildListViewCore({ScrollController? scrollController}) {
    return MaterialApp(
      home: ListViewCore(
        itemCount: 3,
        onFetchData: () {},
        itemBuilder: (context, index) => Text('item $index'),
        scrollController: scrollController,
      ),
    );
  }

  ScrollController scrollableController(WidgetTester tester) {
    return tester
        .widget<Scrollable>(find.byType(Scrollable).first)
        .controller!;
  }

  testWidgets('rebinds CustomScrollView when scrollController is swapped',
      (tester) async {
    final external = ScrollController();

    await tester.pumpWidget(buildListViewCore());
    await tester.pump();
    final initialOwned = scrollableController(tester);

    await tester.pumpWidget(buildListViewCore(scrollController: external));
    await tester.pump();

    expect(scrollableController(tester), same(external));
    expect(
      () => initialOwned.addListener(() {}),
      throwsA(isA<FlutterError>()),
      reason: 'implicit controller must be disposed when switching to external',
    );

    await tester.pumpWidget(buildListViewCore());
    await tester.pump();

    final restoredOwned = scrollableController(tester);
    expect(restoredOwned, isNot(same(external)));
    expect(restoredOwned, isNot(same(initialOwned)));
    expect(
      () => restoredOwned.addListener(() {}),
      returnsNormally,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    external.dispose();
  });
}
