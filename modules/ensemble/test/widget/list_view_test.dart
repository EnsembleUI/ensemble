import 'package:ensemble/layout/list_view.dart' as ensemble;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('ListView preserves its implicit scroll controller on rebuild',
      (tester) async {
    final firstList = ensemble.ListView(key: const ValueKey('list'));

    await tester.pumpWidget(TestUtils.wrapTestWidget(firstList));

    final scrollController = firstList.controller.scrollController;
    expect(scrollController, isNotNull);

    final rebuiltList = ensemble.ListView(key: const ValueKey('list'));

    await tester.pumpWidget(TestUtils.wrapTestWidget(rebuiltList));

    expect(rebuiltList.controller.scrollController, same(scrollController));
  });
}
