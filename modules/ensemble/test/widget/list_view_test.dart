import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/layout/list_view.dart' as ensemble;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  ensemble.ListView listViewWithChild() {
    final widget = ensemble.ListView();
    widget.initChildren(
      children: [
        ViewUtil.buildModel({
          'Text': {'text': 'Item'}
        }, null),
      ],
    );
    return widget;
  }

  ensemble.ListView listViewWithManyChildren({int count = 20}) {
    final widget = ensemble.ListView();
    widget.initChildren(
      children: List.generate(
        count,
        (i) => ViewUtil.buildModel({
          'Text': {'text': 'Item $i'}
        }, null),
      ),
    );
    return widget;
  }

  test('scrollToOffset is a no-op without attached scroll clients', () {
    final controller = ensemble.ListViewController();
    final scrollController = ScrollController();
    controller.scrollController = scrollController;

    expect(() => controller.scrollToOffset(100), returnsNormally);

    scrollController.dispose();
  });

  testWidgets('scrollToOffset jumps to pixel offset when not animated',
      (tester) async {
    final list = listViewWithManyChildren();

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      SizedBox(
        height: 200,
        width: 300,
        child: list,
      ),
    ));
    await tester.pumpAndSettle();

    list.controller.scrollToOffset(80, animated: false);
    await tester.pump();

    expect(list.controller.scrollController!.offset, 80);
  });

  testWidgets('scrollToTop moves list to offset zero', (tester) async {
    final list = listViewWithManyChildren();

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      SizedBox(
        height: 200,
        width: 300,
        child: list,
      ),
    ));
    await tester.pumpAndSettle();

    list.controller.scrollToOffset(80, animated: false);
    await tester.pump();
    expect(list.controller.scrollController!.offset, greaterThan(0));

    list.controller.scrollToTop(animated: false);
    await tester.pump();
    expect(list.controller.scrollController!.offset, 0);
  });

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

  testWidgets('transfers internally-created scroll controller on widget update',
      (tester) async {
    final firstWidget = listViewWithChild();

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(firstWidget));
    final controller = firstWidget.controller.scrollController;
    expect(controller, isNotNull);

    final secondWidget = listViewWithChild();
    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(secondWidget));

    expect(secondWidget.controller.scrollController, same(controller));

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      const SizedBox.shrink(),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);

    expect(
      () => controller!.addListener(() {}),
      throwsA(isA<FlutterError>()),
    );
  });

  testWidgets(
      'restores ListView scroll controller when leaving draggable footer scope',
      (tester) async {
    final footerSheetScroll = ScrollController();
    final dragOptions = DragOptions(
      onMaxSize: null,
      onMinSize: null,
      maxSize: 1.0,
      minSize: 0.25,
      isDraggable: true,
      initialSize: 0.5,
      expand: false,
      snap: false,
      showDragHandle: false,
      snapSizes: null,
    );

    final list = listViewWithChild();

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      SizedBox(
        height: 400,
        width: 400,
        child: list,
      ),
    ));
    await tester.pump();
    final ownedScroll = list.controller.scrollController;
    expect(ownedScroll, isNotNull);
    expect(ownedScroll, isNot(same(footerSheetScroll)));

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      FooterScope(
        scrollController: footerSheetScroll,
        dragOptions: dragOptions,
        child: SizedBox(
          height: 400,
          width: 400,
          child: list,
        ),
      ),
    ));
    await tester.pump();

    expect(list.controller.scrollController, same(footerSheetScroll));

    final scrollableInFooter = tester.widget<Scrollable>(
      find.descendant(
        of: find.byType(ensemble.ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(
      scrollableInFooter.controller,
      same(list.controller.scrollController),
      reason: 'ListViewCore must use the same ScrollController as ListViewController',
    );

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      SizedBox(
        height: 400,
        width: 400,
        child: list,
      ),
    ));
    await tester.pump();

    expect(list.controller.scrollController, same(ownedScroll));
    expect(list.controller.scrollController, isNot(same(footerSheetScroll)));

    final scrollableAfterFooter = tester.widget<Scrollable>(
      find.descendant(
        of: find.byType(ensemble.ListView),
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(
      scrollableAfterFooter.controller,
      same(ownedScroll),
      reason: 'ListViewCore must re-bind to restored controller',
    );

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(const SizedBox.shrink()));
    await tester.pump();
    footerSheetScroll.dispose();
  });
}
