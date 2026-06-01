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

  ensemble.ListView listViewWithItems(int count) {
    final widget = ensemble.ListView();
    widget.initChildren(
      children: List.generate(
        count,
        (index) => ViewUtil.buildModel({
          'Text': {'text': 'Item $index'}
        }, null),
      ),
    );
    return widget;
  }

  ensemble.ListView listViewWithItemTemplate(List<dynamic> data) {
    final widget = ensemble.ListView();
    widget.initChildren(
      itemTemplate: {
        'data': data,
        'name': 'row',
        'template': {
          'Text': {'text': 'Cell'},
        },
      },
    );
    return widget;
  }

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

  group('scroll position control', () {
    test('scrollToOffset is a no-op without an attached scroll controller',
        () {
      final widget = ensemble.ListView();
      expect(() => widget.controller.scrollToOffset(10), returnsNormally);
    });

    testWidgets('scrollToOffset jumps to the requested offset', (tester) async {
      final list = listViewWithItems(50);

      await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
        SizedBox(
          height: 200,
          width: 400,
          child: list,
        ),
      ));
      await tester.pump();

      final controller = list.controller.scrollController!;
      expect(controller.hasClients, isTrue);

      list.controller.scrollToOffset(120, animated: false);
      await tester.pump();

      expect(controller.offset, 120);
    });

    testWidgets('scrollToTop and scrollToBottom move to list edges',
        (tester) async {
      final list = listViewWithItems(50);

      await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
        SizedBox(
          height: 200,
          width: 400,
          child: list,
        ),
      ));
      await tester.pump();

      final controller = list.controller.scrollController!;
      expect(controller.offset, 0);

      list.controller.scrollToBottom(animated: false);
      await tester.pump();
      expect(controller.offset, greaterThan(0));

      list.controller.scrollToTop(animated: false);
      await tester.pump();
      expect(controller.offset, 0);
    });

    testWidgets('scrollToIndex clamps index without throwing for templated data',
        (tester) async {
      final list = listViewWithItemTemplate(
        List.generate(50, (index) => index),
      );

      await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
        SizedBox(
          height: 200,
          width: 400,
          child: list,
        ),
      ));
      await tester.pumpAndSettle();

      expect(list.controller.widgetState?.templatedDataList?.length, 50);

      final controller = list.controller.scrollController!;

      list.controller.scrollToIndex(0, animated: false);
      await tester.pump();
      expect(controller.offset, 0);

      list.controller.scrollToIndex(49, animated: false);
      await tester.pump();
      final offsetNearEnd = controller.offset;
      expect(offsetNearEnd, greaterThan(0));

      expect(
        () => list.controller.scrollToIndex(999, animated: false),
        returnsNormally,
      );
      await tester.pump();
      expect(controller.offset, greaterThan(0));
      expect(
        controller.offset,
        lessThanOrEqualTo(controller.position.maxScrollExtent),
      );

      list.controller.scrollToIndex(-1, animated: false);
      await tester.pump();
      expect(controller.offset, 0);
    });
  });
}
