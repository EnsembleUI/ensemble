
import 'package:carousel_slider/carousel_slider.dart';
import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/layout/layout_helper.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:ensemble/widget/widget_util.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Carousel extends StatefulWidget with UpdatableContainer, Invokable, HasController<MyController, CarouselState> {
  static const type = 'Carousel';
  Carousel({Key? key}) : super(key: key);

  final MyController _controller = MyController();
  @override
  MyController get controller => _controller;

  @override
  CarouselState createState() => CarouselState();

  @override
  Map<String, Function> setters() {
    return {
      'layout': (input) => _controller.layout = CarouselLayout.values.from(input),
      'autoLayoutBreakpoint': (value) => _controller.autoLayoutBreakpoint = Utils.optionalInt(value, min: 0),
      'height': (height) => _controller.height = Utils.optionalInt(height),
      'gap': (gap) => _controller.gap = Utils.optionalInt(gap),
      'indicatorType': (type) => _controller.indicatorType = IndicatorType.values.from(type),
      'indicatorPosition': (position) => _controller.indicatorPosition = IndicatorPosition.values.from(position),
      'indicatorWidth': (w) => _controller.indicatorWidth = Utils.optionalInt(w),
      'indicatorHeight': (h) => _controller.indicatorHeight = Utils.optionalInt(h),
      'indicatorMargin': (value) => _controller.indicatorMargin = Utils.getInsets(value)
    };
  }

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    _controller.itemTemplate = itemTemplate;
  }

}

class MyController extends BoxController {
  static const double defaultItemGap = 10;

  ItemTemplate? itemTemplate;
  List<Widget>? children;

  int? height;
  int? gap; // gap between the children, but also at start and end to properly center

  CarouselLayout? layout;
  int? autoLayoutBreakpoint;    // applicable only for auto layout

  IndicatorType? indicatorType;
  IndicatorPosition? indicatorPosition;
  int? indicatorWidth;
  int? indicatorHeight;
  EdgeInsets? indicatorMargin;
}


class CarouselState extends WidgetState<Carousel> with TemplatedWidgetState {
  List<Widget>? templatedChildren;
  final CarouselController _carouselController = CarouselController();
  int selectedIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // evaluate item-template's initial value & listen for changes
    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(
        context,
        widget._controller.itemTemplate!,
        evaluateInitialValue: true,
        onDataChanged: (List dataList) {
          setState(() {
            templatedChildren = buildWidgetsFromTemplate(context, dataList, widget._controller.itemTemplate!);
          });
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    if (!widget._controller.visible) {
      return const SizedBox.shrink();
    }
    // if we should display one at a time or multiple in the slider
    bool singleView = isSingleView();

    List<Widget> items = buildItems();
    Widget carousel = CarouselSlider(
      options: singleView ? _getSingleViewOptions() : _getMultiViewOptions(),
      items: items,
      carouselController: _carouselController,
    );

    // show indicators
    if (widget._controller.indicatorType != null && widget._controller.indicatorType != IndicatorType.none) {
      List<Widget> indicators = [];
      for (int i=0; i<items.length; i++) {
        indicators.add(GestureDetector(
          child: getIndicator(i == selectedIndex),
          onTap: () => _carouselController.animateToPage(i),
        ));
      }
      // Carousel requires a fixed height, so to make sure the indicators don't shift the UI, we'll make
      // sure there's at least 1 invisible indicator that takes up the space
      if (indicators.isEmpty) {
        indicators.add(Opacity(child: getIndicator(false), opacity: 0));
      }

      List<Widget> children = [
        carousel,
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: indicators
        )
      ];

      carousel = Column(
        children: widget._controller.indicatorPosition == IndicatorPosition.top ? children.reversed.toList() : children
      );
    }

    return WidgetUtils.wrapInBox(carousel, widget._controller);
  }

  /// return if we should display our cards one at a time for the current screen
  bool isSingleView() {
    if (widget._controller.layout == CarouselLayout.single) {
      return true;
    } else if (widget._controller.layout == CarouselLayout.multiple) {
      return false;
    }
    // auto layout is the default
    int cutoff = widget._controller.autoLayoutBreakpoint ?? 768;
    return Ensemble().deviceInfo.size.width < cutoff ? true : false;
  }

  List<Widget> buildItems() {
    // children will be rendered before templated children
    List<Widget> children = [];
    if (widget._controller.children != null) {
      children.addAll(widget._controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }

    // wrap each child inside Container to add padding and gap
    double gap = widget._controller.gap?.toDouble() ?? MyController.defaultItemGap;
    List<Widget> items = [];
    for (int i=0; i<children.length; i++) {
      Widget child = children[i];
      //double leftGap = i == 0 ? gap : gap / 2;
      //double rightGap = i == children.length-1 ? gap : gap / 2;

      items.add(Container(
        margin: EdgeInsets.only(left: gap / 2, right: gap / 2),
        child: child,
      ));
    }
    return items;
  }

  CarouselOptions _getSingleViewOptions() {
    return _getBaseCarouselOptions().copyWith(
      padEnds: true,
      viewportFraction: 1
    );
  }

  CarouselOptions _getMultiViewOptions() {
    return _getBaseCarouselOptions().copyWith(
      disableCenter: true,
      padEnds: false,
      pageSnapping: false,
      viewportFraction: .6,

    );
  }

  CarouselOptions _getBaseCarouselOptions() {
    return CarouselOptions(
      height: widget._controller.height?.toDouble(),
      enableInfiniteScroll: false,
      onPageChanged: (index, _) {
        setState(() {
          selectedIndex = index;
        });
      }
    );
  }

  Widget getIndicator(bool selected) {
    int w = widget._controller.indicatorWidth ?? widget._controller.indicatorHeight ?? 8;
    int h = widget._controller.indicatorHeight ?? widget._controller.indicatorWidth ?? 8;

    return Container(
      width: w.toDouble(),
      height: h.toDouble(),
      margin: widget._controller.indicatorMargin ?? const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      decoration: BoxDecoration(
        shape: widget._controller.indicatorType == IndicatorType.rectangle ? BoxShape.rectangle : BoxShape.circle,
        color: (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black)
            .withOpacity(selected ? 0.9 : 0.4)
      )
    );

  }


}

enum CarouselLayout {
  auto,
  single,
  multiple,
}
enum IndicatorType {
  none,
  circle,
  rectangle,
}
enum IndicatorPosition {
  bottom,
  top
}