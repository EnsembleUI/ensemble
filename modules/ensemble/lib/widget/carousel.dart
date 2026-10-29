import 'package:carousel_slider/carousel_slider.dart';
import 'package:carousel_slider/carousel_slider.dart' as e;
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
import 'package:ensemble/widget/helpers/ColorFilter_Composite.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      'indicatorLeadingWidget': (widget) =>
          _controller.indicatorLeadingWidget = widget,
      'indicatorTrailingWidget': (widget) =>
          _controller.indicatorTrailingWidget = widget,
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
      'scrollType': (value) =>
          _controller.scrollType = CarouselScrollPhysics.values.from(value),
      'colorFilter': (value) => 
          _controller.colorFilter = ColorFilterComposite.from(value)

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
  ColorFilterComposite? colorFilter;
  CarouselScrollPhysics? scrollType; // Use enum instead of string

  // Custom Widget
  dynamic indicatorWidget;
  dynamic selectedIndicatorWidget;
  dynamic indicatorLeadingWidget;
  dynamic indicatorTrailingWidget;

  // for single view the current item index is dispatched,
  // for multi view this dispatch when clicking on a card
  EnsembleAction? onItemTap;
  EnsembleAction? onItemChange;
  int currentIndex = 0;
  int selectedIndex = -1;

  @Deprecated('Use currentIndex instead')
  int selectedItemIndex = 0;
  int? indicatorMaxCount;

  e.CarouselSliderController _carouselController = e.CarouselSliderController();
}

class CarouselState extends EWidgetState<Carousel>
    with TemplatedWidgetState, HasChildren<Carousel> {
  List<Widget>? templatedChildren;

  Widget? customIndicator;
  Widget? selectedCustomIndicator;
  Widget? leadingIndicatorWidget;
  Widget? trailingIndicatorWidget;

  int indicatorIndex = 0;

  // ===========================================================================
  // TV Focus Handling
  // Enables: interceptHorizontalNav, pauseAutoplayOnFocus, restoreFocusOnPageChange
  // ===========================================================================

  /// FocusScope for the entire carousel. Receives delegated horizontal key events.
  final FocusScopeNode _carouselFocusScopeNode = FocusScopeNode(debugLabel: 'CarouselScope');

  /// Tracks autoplay pause state for pauseAutoplayOnFocus feature.
  bool _isAutoplayPaused = false;

  /// Set true when slide change triggered by D-pad navigation.
  bool _pendingFocusRestore = false;

  /// Set while a slide is settling; restored if focus arrives mid-animation.
  bool _restoreFocusOnSettle = false;
  List<Widget> _builtItems = const [];
  bool _settleRestoreForward = true;

  /// Owns the slider controller that carousel_slider attached to this state.
  late final e.CarouselSliderController _sliderController;

  @override
  void initState() {
    super.initState();
    _sliderController = widget._controller._carouselController;
    // Deprecated - Assigning selectedItemIndex to currentIndex for the deprecated property (selectedItemIndex)
    // If currentIndex has value it skip setting the selectedItemIndex to currentIndex
    // NOTE: If both property has value, then it uses the newly introduced property instead of selectedItemIndex
    if (widget._controller.selectedItemIndex != 0 &&
        widget._controller.currentIndex == 0) {
      widget._controller.currentIndex = widget._controller.selectedItemIndex;
    }

    // Set up focus listener for pauseAutoplayOnFocus feature
    _carouselFocusScopeNode.addListener(_onCarouselFocusChanged);
  }

  @override
  void didUpdateWidget(Carousel oldWidget) {
    super.didUpdateWidget(oldWidget);

    // The widget is rebuilt with a fresh controller; keep the attached slider
    // controller and the indices the old one published.
    widget._controller._carouselController = _sliderController;
    widget._controller.currentIndex = oldWidget._controller.currentIndex;
    widget._controller.selectedIndex = oldWidget._controller.selectedIndex;
    widget._controller.selectedItemIndex =
        oldWidget._controller.selectedItemIndex;
  }

  /// Handle focus changes for pauseAutoplayOnFocus feature
  void _onCarouselFocusChanged() {
    final hasFocus = _carouselFocusScopeNode.hasFocus;

    if (widget._controller.tvOptions?.pauseAutoplayOnFocus != true) return;
    if (widget._controller.autoplay != true) return;

    if (hasFocus && !_isAutoplayPaused) {
      // Focus gained - pause autoplay
      _isAutoplayPaused = true;
      _sliderController.stopAutoPlay();
    } else if (!hasFocus && _isAutoplayPaused) {
      // Focus lost - resume autoplay
      _isAutoplayPaused = false;
      _sliderController.startAutoPlay();
    }
  }

  @override
  void dispose() {
    _carouselFocusScopeNode.removeListener(_onCarouselFocusChanged);
    _carouselFocusScopeNode.dispose();
    super.dispose();
  }

  /// Handle TV D-pad key events for interceptHorizontalNav
  /// When a horizontal key event reaches this handler (via lockHorizontalNavigation
  /// delegation from children), switch slides.
  KeyEventResult _handleTVKeyEvent(FocusNode node, KeyEvent event) {
    if (widget._controller.tvOptions?.interceptHorizontalNav != true) {
      return KeyEventResult.ignored;
    }

    // Only handle key down events (not repeats)
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isLeft = event.logicalKey == LogicalKeyboardKey.arrowLeft;
    final isRight = event.logicalKey == LogicalKeyboardKey.arrowRight;

    if (!isLeft && !isRight) {
      return KeyEventResult.ignored;
    }

    // If a horizontal key event reached this handler, it means the focused child
    // delegated it (via delegateHorizontalNavigation). Switch slides.
    if (isLeft) {
      _navigateToPreviousSlide();
    } else {
      _navigateToNextSlide();
    }
    return KeyEventResult.handled;
  }

  /// Number of slides — cheap count from the sources, without rebuilding every
  /// slide widget via buildItems() (which addGesture/Container-wraps 1:1).
  int get _slideCount =>
      (widget._controller.children?.length ?? 0) +
      (templatedChildren?.length ?? 0);

  /// Navigate to previous slide with focus restoration
  ///
  /// Always steps one page in the pressed direction. The loop boundary must not
  /// use an absolute target (`animateToPage(_slideCount - 1)`): carousel_slider
  /// resolves an absolute page from the *fractional* physical page
  /// (`page.toInt()`) plus a closest-route search, while [onPageChanged]
  /// publishes the reported index before the previous animation settles. A
  /// press arriving in that window could therefore resolve to a route that
  /// animates the wrong way. `previousPage()` derives its target from
  /// `page.round() - 1`, so it always moves left.
  void _navigateToPreviousSlide() {
    if (_slideCount == 0) return;

    _pendingFocusRestore =
        widget._controller.tvOptions?.restoreFocusOnPageChange == true;

    final currentIndex = widget._controller.currentIndex;
    if (currentIndex == 0 && widget._controller.enableLoop != true) {
      // Finite carousel: there is no previous slide to move to.
      return;
    }
    _sliderController.previousPage();
  }

  /// Navigate to next slide with focus restoration
  ///
  /// Always steps one page in the pressed direction; see
  /// [_navigateToPreviousSlide] for why the loop boundary does not use
  /// `animateToPage(0)`. `nextPage()` derives its target from
  /// `page.round() + 1`, so a wrap to the first slide never becomes a backward
  /// sweep through the last one.
  void _navigateToNextSlide() {
    if (_slideCount == 0) return;

    _pendingFocusRestore =
        widget._controller.tvOptions?.restoreFocusOnPageChange == true;

    final currentIndex = widget._controller.currentIndex;
    if (currentIndex == _slideCount - 1 &&
        widget._controller.enableLoop != true) {
      // Finite carousel: there is no next slide to move to.
      return;
    }
    _sliderController.nextPage();
  }

  /// Check if this is a TV platform
  bool get _isTVPlatform => Device().isTV;

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
    leadingIndicatorWidget = _buildIndicatorWidget(
        widget._controller.indicatorLeadingWidget, scopeManager);
    trailingIndicatorWidget = _buildIndicatorWidget(
        widget._controller.indicatorTrailingWidget, scopeManager);

    // if we should display one at a time or multiple in the slider
    bool singleView = isSingleView();

    List<Widget> items = buildItems();
    _builtItems = items;
    int buildOnDemandLength = widget._controller.buildOnDemandLength ?? 6;
    bool isBuildOnDemand = widget._controller.buildOnDemand == true &&
        items.length >= buildOnDemandLength;

    Widget carousel = isBuildOnDemand
        ? CarouselSlider.builder(
            itemCount: items.length,
            itemBuilder: (context, itemIndex, pageIndex) => items[itemIndex],
            carouselController: _sliderController,
            options:
                singleView ? _getSingleViewOptions() : _getMultiViewOptions(),
          )
        : CarouselSlider(
            options:
                singleView ? _getSingleViewOptions() : _getMultiViewOptions(),
            carouselController: _sliderController,
            items: items,
          );

    carousel = NotificationListener<ScrollEndNotification>(
      onNotification: (notification) {
        if (notification.depth == 0 && _restoreFocusOnSettle) {
          _restoreFocusOnSettle = false;
          _restoreFocusToCurrentSlide();
        }
        return false;
      },
      child: carousel,
    );

    // show indicators
    if (widget._controller.indicatorType != null &&
        widget._controller.indicatorType != IndicatorType.none) {
      List<Widget> indicators = buildIndicators(items);
      final bool isVertical =
          widget._controller.direction == Axis.vertical.name;
      final Widget indicatorRow = isVertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: indicators,
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: indicators,
            );

      final List<Widget> indicatorChildren = [];

      if (leadingIndicatorWidget != null) {
        indicatorChildren.add(leadingIndicatorWidget!);
      }

      indicatorChildren.add(indicatorRow);

      if (trailingIndicatorWidget != null) {
        indicatorChildren.add(trailingIndicatorWidget!);
      }

      List<Widget> children = [
        carousel,
        Positioned.fill(
          child: Align(
            alignment:
                widget._controller.indicatorPosition ?? Alignment.bottomCenter,
            child: Padding(
              padding: widget._controller.indicatorPadding ?? EdgeInsets.zero,
              child: indicatorChildren.length == 1
                  ? indicatorChildren.first
                  : widget._controller.direction == Axis.vertical.name
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: indicatorChildren,
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: indicatorChildren,
                        ),
            ),
          ),
        )
      ];

      carousel = Stack(clipBehavior: Clip.none, children: children);
    }

    // Wrap with TV focus handling if on TV platform and TV features enabled
    if (_isTVPlatform && _hasTVCarouselFeatures()) {
      carousel = _wrapWithTVFocus(carousel);
    }

    return BoxWrapper(
      widget: carousel,
      boxController: widget._controller,
      ignoresPadding: true,
      ignoresDimension:
          true, // width/height shouldn't be apply in the container
    );
  }

  /// Check if any TV carousel features are enabled
  bool _hasTVCarouselFeatures() {
    final tvOptions = widget._controller.tvOptions;
    return tvOptions?.interceptHorizontalNav == true ||
        tvOptions?.pauseAutoplayOnFocus == true ||
        tvOptions?.restoreFocusOnPageChange == true;
  }

  /// Wrap the carousel with TV focus handling
  Widget _wrapWithTVFocus(Widget carousel) {
    // FocusScope with onKeyEvent - key events from children bubble up
    return FocusScope(
      node: _carouselFocusScopeNode,
      onKeyEvent: _handleTVKeyEvent,
      child: carousel,
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

        _sliderController.animateToPage(index);
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
      if (widget._controller.colorFilter?.color != null) {
        child = ColorFiltered(
          colorFilter: widget._controller.colorFilter!.getColorFilter()!,
          child: child,
        );
      }
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
        final isAutoplay = reason == CarouselPageChangedReason.timed;
        final previousIndex = widget._controller.currentIndex;

        _onItemChange(index);
        setState(() {
          widget._controller.currentIndex = index;
          widget._controller.selectedItemIndex = index;
        });

        // Focus may enter mid-slide; retry once the page settles.
        _prepareFocusRestore(index, previousIndex, isAutoplay);
        _handleFocusRestoration(index, isAutoplay);
      },
    );
  }

  CarouselOptions _getMultiViewOptions() {
    return _getBaseCarouselOptions().copyWith(
        disableCenter: true,
        padEnds: false,
        pageSnapping: false,
        viewportFraction: widget._controller.multipleItemWidthRatio ?? 0.6,
        onPageChanged: (index, reason) {
          final isAutoplay = reason == CarouselPageChangedReason.timed;
          final previousIndex = widget._controller.currentIndex;

          setState(() {
            widget._controller.currentIndex = index;
            widget._controller.selectedItemIndex = index;
            updateIndicatorIndex();
          });

          // Focus may enter mid-slide; retry once the page settles.
          _prepareFocusRestore(index, previousIndex, isAutoplay);
          _handleFocusRestoration(index, isAutoplay);
        });
  }

  /// Restores focus to the new slide after page change.
  ///
  /// Called after slide animation completes. Only runs if:
  /// - restoreFocusOnPageChange is enabled
  /// - Carousel currently has focus
  ///
  /// Focus lands on the first focusable of the new slide (Flutter's default
  /// forward traversal) regardless of navigation direction.
  void _handleFocusRestoration(int newIndex, bool isAutoplay) {
    if (!_isTVPlatform) return;
    if (widget._controller.tvOptions?.restoreFocusOnPageChange != true) return;

    // Only restore if carousel has focus (prevents stealing focus during autoplay)
    final carouselHasFocus = _carouselFocusScopeNode.hasFocus;
    if (!carouselHasFocus) {
      _pendingFocusRestore = false;
      return;
    }

    // Manual nav needs _pendingFocusRestore, autoplay always restores if has focus
    if (!_pendingFocusRestore && !isAutoplay) return;

    _pendingFocusRestore = false;
    _restoreFocusOnSettle = false;

    // Wait one frame for new slide widgets to be built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_carouselFocusScopeNode.hasFocus) return;

      // Land focus on the first focusable of the new slide (Flutter's default
      // forward traversal). This is the intended behavior for both directions.
      _carouselFocusScopeNode.nextFocus();
    });
  }

  void _prepareFocusRestore(int index, int previousIndex, bool isAutoplay) {
    // Multi-view keeps several items on screen, so the focused one need not be
    // the current page.
    _restoreFocusOnSettle = isSingleView() &&
        widget._controller.tvOptions?.restoreFocusOnPageChange == true;
    _settleRestoreForward = isAutoplay || index > previousIndex;
  }

  /// Focus that entered after [onPageChanged] sits on the slide that just
  /// moved away; move it to the current slide once the page settles.
  void _restoreFocusToCurrentSlide() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_carouselFocusScopeNode.hasFocus) return;

      final focusedContext = FocusManager.instance.primaryFocus?.context;
      final current = widget._controller.currentIndex;
      if (focusedContext == null ||
          current < 0 ||
          current >= _builtItems.length) {
        return;
      }

      var onCurrentSlide = false;
      focusedContext.visitAncestorElements((element) {
        if (identical(element.widget, _builtItems[current])) {
          onCurrentSlide = true;
          return false;
        }
        return true;
      });
      if (onCurrentSlide) return;

      if (_settleRestoreForward) {
        _carouselFocusScopeNode.nextFocus();
      } else {
        _carouselFocusScopeNode.previousFocus();
      }
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
      scrollPhysics: getScrollPhysics(widget._controller.scrollType),
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
        color: indicatorColor.withValues(alpha: selected ? 0.9 : 0.4),
      ),
    );
  }

  ScrollPhysics getScrollPhysics(CarouselScrollPhysics? physics) {
    if (physics == null) {
      // Platform-specific default behavior
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        return BouncingScrollPhysics(); // Default for iOS
      } else {
        return ClampingScrollPhysics(); // Default for other platforms like Android
      }
    }

    switch (physics) {
      case CarouselScrollPhysics.bouncing:
        return BouncingScrollPhysics();
      case CarouselScrollPhysics.clamping:
        return ClampingScrollPhysics();
      case CarouselScrollPhysics.neverScrollable:
        return NeverScrollableScrollPhysics();
      case CarouselScrollPhysics.alwaysScrollable:
        return AlwaysScrollableScrollPhysics();
      default:
        return ClampingScrollPhysics(); // Fallback for any undefined cases
    }
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

enum CarouselScrollPhysics {
  bouncing,
  clamping,
  neverScrollable,
  alwaysScrollable,
}
