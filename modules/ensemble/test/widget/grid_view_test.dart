import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/layout/grid_view.dart' as ensemble;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_utils.dart';

void main() {
  ensemble.GridView gridViewWithItemTemplate() {
    final widget = ensemble.GridView();
    widget.initChildren(
      itemTemplate: {
        'data': [1],
        'name': 'row',
        'template': {
          'Text': {'text': 'Cell'},
        },
      },
    );
    return widget;
  }

  testWidgets(
      'restores GridView scroll controller when leaving draggable footer scope',
      (tester) async {
    final footerSheetScroll = ScrollController();
    final userScroll = ScrollController();
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

    final grid = gridViewWithItemTemplate();
    grid.setProperty('scrollController', userScroll);

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      SizedBox(
        height: 400,
        width: 400,
        child: grid,
      ),
    ));
    await tester.pump();

    expect(grid.controller.scrollController, same(userScroll));
    expect(grid.controller.scrollController, isNot(same(footerSheetScroll)));

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      FooterScope(
        scrollController: footerSheetScroll,
        dragOptions: dragOptions,
        child: SizedBox(
          height: 400,
          width: 400,
          child: grid,
        ),
      ),
    ));
    await tester.pump();

    expect(grid.controller.scrollController, same(footerSheetScroll));

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
      SizedBox(
        height: 400,
        width: 400,
        child: grid,
      ),
    ));
    await tester.pump();

    expect(grid.controller.scrollController, same(userScroll));
    expect(grid.controller.scrollController, isNot(same(footerSheetScroll)));

    await tester.pumpWidget(
        TestUtils.wrapTestWidgetWithScope(const SizedBox.shrink()));
    await tester.pump();

    userScroll.dispose();
    footerSheetScroll.dispose();
  });
}
