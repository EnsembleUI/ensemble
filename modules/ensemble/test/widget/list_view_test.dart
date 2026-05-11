import 'package:ensemble/layout/list_view.dart' as ensemble;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  testWidgets('disposes internally-created scroll controller', (tester) async {
    final widget = ensemble.ListView();

    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));
    final controller = widget.controller.scrollController;
    expect(controller, isNotNull);

    await tester.pumpWidget(TestUtils.wrapTestWidget(const SizedBox.shrink()));
    await tester.pump();

    expect(
      () => controller!.addListener(() {}),
      throwsA(isA<FlutterError>()),
    );
  });

  testWidgets('does not dispose caller-provided scroll controller',
      (tester) async {
    final scrollController = ScrollController();
    final widget = ensemble.ListView();
    widget.setProperty('controller', scrollController);

    await tester.pumpWidget(TestUtils.wrapTestWidget(widget));
    await tester.pumpWidget(TestUtils.wrapTestWidget(const SizedBox.shrink()));
    await tester.pump();

    expect(() => scrollController.addListener(() {}), returnsNormally);
    scrollController.dispose();
  });
}
