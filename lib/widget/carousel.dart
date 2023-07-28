import 'package:carousel_slider/carousel_slider.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/page.dart';
import 'package:ensemble/framework/widget/screen.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class Carousel extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<MyController, CarouselState> {
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
      'layout': (input) =>
          _controller.layout = CarouselLayout.values.from(input),
      'autoLayoutBreakpoint': (value) =>
          _controller.autoLayoutBreakpoint = Utils.optionalInt(value, min: 0),
      'autoplay': (value) => _controller.autoplay = Utils.optionalBool(value),
      'autoplayInterval': (value) =>
          _controller.autoplayInterval = Utils.optionalInt(value, min: 1),
      'height': (height) => _controller.height = Utils.optionalInt(height),
      'gap': (gap) => _controller.gap = Utils.optionalInt(gap),
      'leadingGap': (gap) => _controller.leadingGap = Utils.optionalInt(gap),
      'trailingGap': (gap) => _controller.trailingGap = Utils.optionalInt(gap),
      'singleItemWidthRatio': (value) => _controller.singleItemWidthRatio =
          Utils.optionalDouble(value, min: 0, max: 1),
      'multipleItemWidthRatio': (value) => _controller.multipleItemWidthRatio =
          Utils.optionalDouble(value, min: 0, max: 1),
      'indicatorType': (type) =>
          _controller.indicatorType = IndicatorType.values.from(type),
      'indicatorPosition': (position) => _controller.indicatorPosition =
          IndicatorPosition.values.from(position),
      'indicatorWidth': (w) =>
          _controller.indicatorWidth = Utils.optionalInt(w),
      'indicatorHeight': (h) =>
          _controller.indicatorHeight = Utils.optionalInt(h),
      'indicatorMargin': (value) =>
          _controller.indicatorMargin = Utils.getInsets(value),
      'indicatorOffset': (value) =>
          _controller.indicatorOffset = Utils.optionalDouble(value),
      'indicatorColor': (value) =>
          _controller.indicatorColor = Utils.getColor(value),
      'onItemChange': (action) => _controller.onItemChange =
          EnsembleAction.fromYaml(action, initiator: this),
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'indicatorWidget': (widget) => _controller.indicatorWidget = widget,
      'selectedIndicatorWidget': (widget) =>
          _controller.selectedIndicatorWidget = widget,
    };
  }

  @override
  Map<String, Function> getters() {
    return {
      'selectedItemIndex': () => _controller.selectedItemIndex,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'next': () {
        _controller._carouselController.nextPage();
      },
      'previous': () {
        _controller._carouselController.previousPage();
      }
    };
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

  int? gap; // gap between the children

  // empty spaces at the start and end. Note that this is different
  // than the container's padding, which always maintain spaces around the container.
  // leadingGap and trailingGap maybe the same visually on load, but on scrolling
  // the content will scroll to the container's edge
  int? leadingGap;
  int? trailingGap;

  double? singleItemWidthRatio;
  double? multipleItemWidthRatio;

  CarouselLayout? layout;
  int? autoLayoutBreakpoint; // applicable only for auto layout

  IndicatorType? indicatorType;
  IndicatorPosition? indicatorPosition;
  int? indicatorWidth;
  int? indicatorHeight;
  EdgeInsets? indicatorMargin;
  double? indicatorOffset;
  Color? indicatorColor;
  bool? autoplay;
  int? autoplayInterval;

  // Custom Widget
  dynamic indicatorWidget;
  dynamic selectedIndicatorWidget;

  // for single view the current item index is dispatched,
  // for multi view this dispatch when clicking on a card
  EnsembleAction? onItemTap;
  EnsembleAction? onItemChange;
  int selectedItemIndex = -1;

  final CarouselController _carouselController = CarouselController();
}

class CarouselState extends WidgetState<Carousel> with TemplatedWidgetState {
  List<Widget>? templatedChildren;

  Widget? customIndicator;
  Widget? selectedCustomIndicator;

  // this is used to highlight the correct indicator index
  int focusIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // evaluate item-template's initial value & listen for changes
    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(context, widget._controller.itemTemplate!,
          evaluateInitialValue: true, onDataChanged: (List dataList) {
        setState(() {
          templatedChildren = buildWidgetsFromTemplate(
              context, dataList, widget._controller.itemTemplate!);
        });
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);

    customIndicator =
        _buildIndicatorWidget(widget._controller.indicatorWidget, scopeManager);
    selectedCustomIndicator = _buildIndicatorWidget(
        widget._controller.selectedIndicatorWidget, scopeManager);

    // if we should display one at a time or multiple in the slider
    bool singleView = isSingleView();

    List<Widget> items = buildItems();
    Widget carousel = CarouselSlider(
      options: singleView ? _getSingleViewOptions() : _getMultiViewOptions(),
      items: items,
      carouselController: widget._controller._carouselController,
    );

    // show indicators
    if (widget._controller.indicatorType != null &&
        widget._controller.indicatorType != IndicatorType.none) {
      List<Widget> indicators = [];
      for (int i = 0; i < items.length; i++) {
        indicators.add(GestureDetector(
          child: getIndicator(i == focusIndex),
          onTap: () {
            // MultiView only dispatch itemChange when explicitly clicking on the item
            // But here since we are selecting the indicator, this should be the
            // same as if you are selecting the item, hence dispatch the item here
            if (!singleView) {
              _onItemChange(i);
            }

            widget._controller._carouselController.animateToPage(i);
          },
        ));
      }
      // Carousel requires a fixed height, so to make sure the indicators don't shift the UI, we'll make
      // sure there's at least 1 invisible indicator that takes up the space
      if (indicators.isEmpty) {
        indicators.add(Opacity(child: getIndicator(false), opacity: 0));
      }

      final double indicatorOffset = widget._controller.indicatorOffset ?? 0;
      final bool isBottom =
          widget._controller.indicatorPosition != IndicatorPosition.top;

      List<Widget> children = [
        carousel,
        Positioned(
          top: !isBottom ? indicatorOffset : null,
          bottom: isBottom ? indicatorOffset : null,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: indicators,
          ),
        )
      ];

      carousel = Stack(clipBehavior: Clip.none, children: children);
    }

    return BoxWrapper(
      widget: carousel,
      boxController: widget._controller,
      ignoresPadding: true,
      ignoresDimension:
          true, // width/height shouldn't be apply in the container
    );
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
    return Device().screenWidth < cutoff ? true : false;
  }

  List<Widget> buildItems() {
    ViewUtil.checkValidWidget(
        widget._controller.children, widget._controller.itemTemplate);

    // children will be rendered before templated children
    List<Widget> children = [];

    if (widget._controller.children != null) {
      children.addAll(widget._controller.children!);
    }

    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }

    if (widget._controller.onItemTap != null) {
      children = ViewUtil.addGesture(children, _onItemTap);
    }

    // wrap each child inside Container to add padding and gap
    double gap =
        widget._controller.gap?.toDouble() ?? MyController.defaultItemGap;
    double leadingGap = widget._controller.leadingGap?.toDouble() ?? 0;
    double trailingGap = widget._controller.trailingGap?.toDouble() ?? 0;
    List<Widget> items = [];
    for (int i = 0; i < children.length; i++) {
      Widget child = children[i];

      items.add(
        Padding(
          padding: EdgeInsets.only(
              left: i == 0 ? leadingGap : gap / 2,
              right: i == children.length - 1 ? trailingGap : gap / 2),
          child: child,
        ),
      );
    }
    return items;
  }

  void _onItemTap(int index) {
    if (widget.controller.onItemTap != null) {
      widget._controller.selectedItemIndex = index;
      ScreenController().executeAction(context, widget._controller.onItemTap!);
    }
  }

  _onItemChange(int index) {
    if (index != widget._controller.selectedItemIndex &&
        widget._controller.onItemChange != null) {
      widget._controller.selectedItemIndex = index;
      //log("Changed to index $index");
      ScreenController()
          .executeAction(context, widget._controller.onItemChange!);
    }
  }

  CarouselOptions _getSingleViewOptions() {
    return _getBaseCarouselOptions().copyWith(
      padEnds: false,
      viewportFraction: widget._controller.singleItemWidthRatio ?? 1,
      onPageChanged: (index, reason) {
        _onItemChange(index);
        setState(() {
          focusIndex = index;
        });
      },
    );
  }

  CarouselOptions _getMultiViewOptions() {
    return _getBaseCarouselOptions().copyWith(
        disableCenter: true,
        padEnds: false,
        pageSnapping: false,
        viewportFraction: widget._controller.multipleItemWidthRatio ?? 0.6,
        onPageChanged: (index, _) {
          setState(() {
            focusIndex = index;
          });
        });
  }

  CarouselOptions _getBaseCarouselOptions() {
    return CarouselOptions(
      height: widget._controller.height?.toDouble(),
      enableInfiniteScroll: false,
      autoPlay: widget._controller.autoplay ?? false,
      autoPlayInterval:
          Duration(seconds: widget._controller.autoplayInterval ?? 4),
    );
  }

  Widget? _buildIndicatorWidget(
      dynamic widgetDefinition, ScopeManager? scopeManager) {
    if (scopeManager != null && widgetDefinition != null) {
      return scopeManager.buildWidgetFromDefinition(widgetDefinition);
    }
    return null;
  }

  /// If it's a custom widget indicator type.
  /// Return the custom indicator widget
  /// Else return the default indicator widget (circle or rectangle)
  Widget getIndicator(bool selected) {
    if (widget.controller.indicatorType == IndicatorType.custom) {
      return selected
          ? selectedCustomIndicator ?? defaultIndicator(selected)
          : customIndicator ?? defaultIndicator(selected);
    }
    return selected ? defaultIndicator(selected) : defaultIndicator(selected);
  }

  Widget defaultIndicator(bool selected) {
    int w = widget._controller.indicatorWidth ??
        widget._controller.indicatorHeight ??
        8;
    int h = widget._controller.indicatorHeight ??
        widget._controller.indicatorWidth ??
        8;

    final Color? indicatorColor = widget._controller.indicatorColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : Colors.black);

    return Container(
      width: w.toDouble(),
      height: h.toDouble(),
      margin: widget._controller.indicatorMargin ??
          const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      decoration: BoxDecoration(
        shape: widget._controller.indicatorType == IndicatorType.rectangle
            ? BoxShape.rectangle
            : BoxShape.circle,
        color: indicatorColor?.withOpacity(selected ? 0.9 : 0.4),
      ),
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
  custom,
}

enum IndicatorPosition { bottom, top }
