import 'package:carousel_slider/carousel_slider.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
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
      'enableLoop': (value) =>
          _controller.enableLoop = Utils.optionalBool(value),
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
      'indicatorPosition': (position) =>
          _controller.indicatorPosition = Utils.getAlignment(position),
      'indicatorWidth': (w) =>
          _controller.indicatorWidth = Utils.optionalInt(w),
      'indicatorHeight': (h) =>
          _controller.indicatorHeight = Utils.optionalInt(h),
      'indicatorMargin': (value) =>
          _controller.indicatorMargin = Utils.getInsets(value),
      'indicatorPadding': (value) =>
          _controller.indicatorPadding = Utils.getInsets(value),
      'indicatorColor': (value) =>
          _controller.indicatorColor = Utils.getColor(value),
      'currentIndex': (value) =>
          _controller.currentIndex = Utils.getInt(value, fallback: 0),
      'selectedItemIndex': (value) =>
          _controller.selectedItemIndex = Utils.getInt(value, fallback: 0),
      'indicatorMaxCount': (value) =>
          _controller.indicatorMaxCount = Utils.optionalInt(value),
      'onItemChange': (action) => _controller.onItemChange =
          EnsembleAction.from(action, initiator: this),
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          EnsembleAction.from(funcDefinition, initiator: this),
      'indicatorWidget': (widget) => _controller.indicatorWidget = widget,
      'selectedIndicatorWidget': (widget) =>
          _controller.selectedIndicatorWidget = widget,
      'aspectRatio': (value) =>
          _controller.aspectRatio = Utils.optionalDouble(value),
      'autoPlayAnimationDuration': (value) =>
          _controller.autoPlayAnimationDuration = Utils.optionalInt(value),
      'autoPlayCurve': (value) =>
          _controller.autoPlayCurve = Utils.getCurve(value),
      'enlargeCenterPage': (value) =>
          _controller.enlargeCenterPage = Utils.optionalBool(value),
      'buildOnDemand': (value) =>
          _controller.buildOnDemand = Utils.optionalBool(value),
      'buildOnDemandLength': (value) =>
          _controller.buildOnDemandLength = Utils.optionalInt(value),
      'enlargeFactor': (value) =>
          _controller.enlargeFactor = Utils.optionalDouble(value),
      'direction': (value) =>
          _controller.direction = Utils.optionalString(value),
      'cacheKey': (value) => _controller.cacheKey = Utils.optionalString(value),
    };
  }

  @override
  Map<String, Function> getters() {
    return {
      'currentIndex': () => _controller.currentIndex,
      'selectedIndex': () => _controller.selectedIndex,
      'selectedItemIndex': () => _controller.selectedItemIndex,
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'next': () => _controller._carouselController.nextPage(),
      'previous': () => _controller._carouselController.previousPage(),
      'startAutoplay': () => _controller._carouselController.startAutoPlay(),
      'stopAutoplay': () => _controller._carouselController.stopAutoPlay(),
      'animateToPage': (int page, [int? duration, String? curve]) {
        _controller._carouselController.animateToPage(
          page,
          duration: Utils.getDurationMs(duration) ??
              const Duration(milliseconds: 300),
          curve: Utils.getCurve(curve) ?? Curves.linear,
        );
      },
      'jumpToPage': (int page) =>
          _controller._carouselController.jumpToPage(page)
    };
  }

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    _controller.children = children;
    _controller.itemTemplate = ItemTemplate.from(itemTemplate);
  }
}

class MyController extends BoxController {
  static const double defaultItemGap = 10;

  ItemTemplate? itemTemplate;
  List<WidgetModel>? children;

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
  Alignment? indicatorPosition;
  int? indicatorWidth;
  int? indicatorHeight;
  EdgeInsets? indicatorMargin;
  EdgeInsets? indicatorPadding;
  Color? indicatorColor;
  bool? autoplay;
  bool? enableLoop;
  int? autoplayInterval;
  int? autoPlayAnimationDuration;
  double? aspectRatio;
  double? enlargeFactor;
  Curve? autoPlayCurve;
  bool? enlargeCenterPage;
  bool? buildOnDemand;
  int? buildOnDemandLength;
  String? direction;
  String? cacheKey;

  // Custom Widget
  dynamic indicatorWidget;
  dynamic selectedIndicatorWidget;

  // for single view the current item index is dispatched,
  // for multi view this dispatch when clicking on a card
  EnsembleAction? onItemTap;
  EnsembleAction? onItemChange;
  int currentIndex = 0;
  int selectedIndex = -1;

  @Deprecated('Use currentIndex instead')
  int selectedItemIndex = 0;
  int? indicatorMaxCount;

  final CarouselController _carouselController = CarouselController();
}

class CarouselState extends WidgetState<Carousel>
    with TemplatedWidgetState, HasChildren<Carousel> {
  List<Widget>? templatedChildren;

  Widget? customIndicator;
  Widget? selectedCustomIndicator;

  int indicatorIndex = 0;

  @override
  void initState() {
    super.initState();
    // Deprecated - Assigning selectedItemIndex to currentIndex for the deprecated property (selectedItemIndex)
    // If currentIndex has value it skip setting the selectedItemIndex to currentIndex
    // NOTE: If both property has value, then it uses the newly introduced property instead of selectedItemIndex
    if (widget._controller.selectedItemIndex != 0 &&
        widget._controller.currentIndex == 0) {
      widget._controller.currentIndex = widget._controller.selectedItemIndex;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // evaluate item-template's initial value & listen for changes
    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(context, widget._controller.itemTemplate!,
          onDataChanged: (List dataList) {
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
    int buildOnDemandLength = widget._controller.buildOnDemandLength ?? 6;
    bool isBuildOnDemand = widget._controller.buildOnDemand == true &&
        items.length >= buildOnDemandLength;

    Widget carousel = isBuildOnDemand
        ? CarouselSlider.builder(
            itemCount: items.length,
            itemBuilder: (context, itemIndex, pageIndex) => items[itemIndex],
            options:
                singleView ? _getSingleViewOptions() : _getMultiViewOptions(),
          )
        : CarouselSlider(
            options:
                singleView ? _getSingleViewOptions() : _getMultiViewOptions(),
            carouselController: widget._controller._carouselController,
            items: items,
          );

    // show indicators
    if (widget._controller.indicatorType != null &&
        widget._controller.indicatorType != IndicatorType.none) {
      List<Widget> indicators = buildIndicators(items);

      List<Widget> children = [
        carousel,
        Positioned.fill(
          child: Align(
            alignment:
                widget._controller.indicatorPosition ?? Alignment.bottomCenter,
            child: Padding(
              padding: widget._controller.indicatorPadding ?? EdgeInsets.zero,
              child: widget._controller.direction == Axis.vertical.name
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: indicators,
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: indicators,
                    ),
            ),
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

  List<Widget> buildIndicators(List<Widget> items) {
    List<Widget> indicators = [];
    if (widget._controller.indicatorMaxCount == null ||
        widget._controller.indicatorMaxCount! > items.length) {
      // Default
      for (int i = 0; i < items.length; i++) {
        indicators.add(buildIndicatorItem(
            index: i, isSelected: i == widget._controller.currentIndex));
      }
    } else {
      // Custom Indicator Logic using the indicatorMaxCount property - Indicator size is not same as item size.
      if (widget._controller.indicatorMaxCount! < items.length) {
        // Modify indicatorIndex to set the currentIndex as indicatorIndex if it's less than the indicatorMaxCount
        // Else it'll set the indicatorIndex as zero
        if (widget._controller.currentIndex <
            widget._controller.indicatorMaxCount!) {
          indicatorIndex = widget._controller.currentIndex;
        }

        for (int i = 0; i < widget._controller.indicatorMaxCount!; i++) {
          indicators.add(
              buildIndicatorItem(index: i, isSelected: i == indicatorIndex));
        }
      }
    }

    // Carousel requires a fixed height, so to make sure the indicators don't shift the UI, we'll make
    // sure there's at least 1 invisible indicator that takes up the space
    if (indicators.isEmpty) {
      indicators.add(buildIndicatorItem());
    }
    return indicators;
  }

  Widget buildIndicatorItem({int? index, bool? isSelected}) {
    if (index == null || isSelected == null) {
      return Opacity(opacity: 0, child: getIndicator(false));
    }
    return GestureDetector(
      child: getIndicator(isSelected),
      onTap: () {
        // MultiView only dispatch itemChange when explicitly clicking on the item
        // But here since we are selecting the indicator, this should be the
        // same as if you are selecting the item, hence dispatch the item here
        if (!isSingleView()) {
          _onItemChange(index);
        }

        widget._controller._carouselController.animateToPage(index);
      },
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
    // children will be rendered before templated children
    List<Widget> children = [];

    if (widget._controller.children != null) {
      children.addAll(buildChildren(widget._controller.children!));
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
      widget._controller.currentIndex = index;
      widget._controller.selectedIndex = index;
      widget._controller.selectedItemIndex = index;
      ScreenController().executeAction(context, widget._controller.onItemTap!);
    }
  }

  void _onItemChange(int index) {
    if (index != widget._controller.currentIndex &&
        widget._controller.onItemChange != null) {
      widget._controller.currentIndex = index;
      widget._controller.selectedItemIndex = index;
      updateIndicatorIndex();
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
          widget._controller.currentIndex = index;
          widget._controller.selectedItemIndex = index;
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
            widget._controller.currentIndex = index;
            widget._controller.selectedItemIndex = index;
            updateIndicatorIndex();
          });
        });
  }

  /// This method will increment the indicator based on the indicatorMaxCount property
  /// If the indicatorMaxCount property is null, the indicatorIndex will have the currentIndex
  /// Or else, the indicatorIndex will INCREMENT if the indicator is less than indicatorMaxCount or RESET the indicatorIndex to zero
  void updateIndicatorIndex() {
    final currentIndex = widget._controller.currentIndex;
    if (widget._controller.indicatorMaxCount != null) {
      if (indicatorIndex < widget._controller.indicatorMaxCount! - 1) {
        // Increment the indicator index
        indicatorIndex++;
      } else {
        //  Reset the indicator index
        indicatorIndex = 0;
      }
    } else {
      indicatorIndex = currentIndex;
    }
  }

  CarouselOptions _getBaseCarouselOptions() {
    return CarouselOptions(
      height: widget._controller.height?.toDouble(),
      initialPage: widget._controller.currentIndex,
      enableInfiniteScroll: widget._controller.enableLoop ?? false,
      autoPlay: widget._controller.autoplay ?? false,
      autoPlayInterval:
          Duration(seconds: widget._controller.autoplayInterval ?? 4),
      aspectRatio: widget._controller.aspectRatio ?? 16 / 9,
      autoPlayAnimationDuration: Duration(
          milliseconds: widget._controller.autoPlayAnimationDuration ?? 800),
      autoPlayCurve: widget._controller.autoPlayCurve ?? Curves.fastOutSlowIn,
      enlargeCenterPage: widget._controller.enlargeCenterPage,
      enlargeFactor: widget._controller.enlargeFactor ?? 0.3,
      scrollDirection: widget._controller.direction == Axis.vertical.name
          ? Axis.vertical
          : Axis.horizontal,
      pageViewKey: widget._controller.cacheKey != null
          ? PageStorageKey<String>(widget._controller.cacheKey!)
          : null,
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

    final Color indicatorColor = widget._controller.indicatorColor ??
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
        color: indicatorColor.withOpacity(selected ? 0.9 : 0.4),
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
