import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/util/debouncer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' as flutter;

typedef ItemBuilder = Widget Function(BuildContext context, int index);

class _ContextualSliverPadding extends StatelessWidget {
  const _ContextualSliverPadding({
    required this.scrollDirection,
    required this.sliver,
    this.padding,
  });

  final EdgeInsets? padding;
  final Axis scrollDirection;
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    EdgeInsetsGeometry? effectivePadding = padding;
    final mediaQuery = MediaQuery.maybeOf(context);

    var sliver = this.sliver;
    if (padding == null) {
      if (mediaQuery != null) {
        late final mediaQueryHorizontalPadding =
            mediaQuery.padding.copyWith(top: 0, bottom: 0);
        late final mediaQueryVerticalPadding =
            mediaQuery.padding.copyWith(left: 0, right: 0);
        effectivePadding = scrollDirection == Axis.vertical
            ? mediaQueryVerticalPadding
            : mediaQueryHorizontalPadding;
        sliver = MediaQuery(
          data: mediaQuery.copyWith(
            padding: scrollDirection == Axis.vertical
                ? mediaQueryHorizontalPadding
                : mediaQueryVerticalPadding,
          ),
          child: sliver,
        );
      }
    }

    if (effectivePadding != null) {
      sliver = SliverPadding(padding: effectivePadding, sliver: sliver);
    }
    return sliver;
  }
}

class ListViewCore extends StatefulWidget {
  const ListViewCore({
    required this.itemCount,
    required this.onFetchData,
    required this.itemBuilder,
    super.key,
    this.shrinkWrap = false,
    this.nestedScroll = false,
    this.scrollController,
    this.scrollDirection = Axis.vertical,
    this.physics,
    this.cacheExtent,
    this.debounceDuration = const Duration(milliseconds: 100),
    this.reverse = false,
    this.isLoading = false,
    this.hasError = false,
    this.hasReachedMax = false,
    this.padding,
    this.emptyBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.separatorBuilder,
    this.onScroll,
  });

  final bool shrinkWrap;
  final bool nestedScroll;
  final ScrollController? scrollController;
  final Axis scrollDirection;
  final ScrollPhysics? physics;
  final Duration debounceDuration;
  final bool reverse;
  final int itemCount;
  final bool isLoading;
  final bool hasError;
  final bool hasReachedMax;
  final VoidCallback onFetchData;
  final double? cacheExtent;
  final EdgeInsets? padding;
  final WidgetBuilder? emptyBuilder;
  final WidgetBuilder? loadingBuilder;
  final WidgetBuilder? errorBuilder;
  final IndexedWidgetBuilder? separatorBuilder;
  final ItemBuilder itemBuilder;
  final void Function(double)? onScroll;

  @override
  State<ListViewCore> createState() => _ListViewCoreState();
}

class _ListViewCoreState extends State<ListViewCore> {
  late final Debouncer debounce;
  late final Debouncer _scrollDebouce;
  late final ScrollController _scrollController;

  int? _lastFetchedIndex;

  @override
  void initState() {
    super.initState();
    debounce = Debouncer(widget.debounceDuration);
    _scrollDebouce = Debouncer(const Duration(milliseconds: 15));
    _scrollController = widget.scrollController ?? ScrollController();
    _scrollController.addListener(_onScroll);

    attemptFetch();
  }

  @override
  void didUpdateWidget(ListViewCore oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasReachedMax && oldWidget.hasReachedMax) {
      attemptFetch();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    debounce.cancel();
    _scrollDebouce.cancel();
    super.dispose();
  }

  void attemptFetch() {
    if (!widget.hasReachedMax && !widget.isLoading && !widget.hasError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debounce.run(widget.onFetchData);
      });
    }
  }

  void onBuiltLast(int lastItemIndex) {
    if (_lastFetchedIndex != lastItemIndex) {
      _lastFetchedIndex = lastItemIndex;
      attemptFetch();
    }
  }

  void _onScroll() {
    if (widget.onScroll != null) {
      _scrollDebouce.run(() {
        widget.onScroll?.call(_scrollController.position.pixels);
      });
    }
    // listView's scrollController is in sync with externalScrollController
    // given the nestedScroll property is set to true and View is Scrollable
    // Note that we are not using jumpTo to avoid jerky movement of external
    // Scroll instead we are using animateTo which is smoother than jumpTo
    if (externalScrollController != null &&
        widget.nestedScroll &&
        widget.shrinkWrap) {
      final currentOffset = _scrollController.position.pixels;

      externalScrollController!.animateTo(
        currentOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  WidgetBuilder get loadingBuilder =>
      widget.loadingBuilder ??
      (context) => const Center(child: flutter.CircularProgressIndicator());

  WidgetBuilder get errorBuilder =>
      widget.errorBuilder ?? (context) => const Center(child: Text('Error'));

  @override
  Widget build(BuildContext context) {
    final hasItems = widget.itemCount != 0;

    final showEmpty = !widget.isLoading &&
        widget.itemCount == 0 &&
        widget.emptyBuilder != null;
    final showBottomWidget = showEmpty || widget.isLoading || widget.hasError;
    final showSeparator = widget.separatorBuilder != null;
    final separatorCount = !showSeparator ? 0 : widget.itemCount - 1;

    final effectiveItemCount =
        (!hasItems ? 0 : widget.itemCount + separatorCount) +
            (showBottomWidget ? 1 : 0);
    final lastItemIndex = effectiveItemCount - 1;

    return CustomScrollView(
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      shrinkWrap: widget.shrinkWrap,
      controller: _scrollController,
      physics: widget.physics,
      cacheExtent: widget.cacheExtent,
      slivers: [
        _ContextualSliverPadding(
          padding: widget.padding,
          scrollDirection: widget.scrollDirection,
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              childCount: effectiveItemCount,
              (context, index) {
                if (index == lastItemIndex) {
                  onBuiltLast(lastItemIndex);
                }
                if (index == lastItemIndex && showBottomWidget) {
                  if (widget.hasError) {
                    return errorBuilder(context);
                  } else if (widget.isLoading) {
                    return loadingBuilder(context);
                  } else {
                    return widget.emptyBuilder!(context);
                  }
                } else {
                  final itemIndex =
                      !showSeparator ? index : (index / 2).floor();
                  if (showSeparator && index.isOdd) {
                    return widget.separatorBuilder!(context, itemIndex);
                  } else {
                    return widget.itemBuilder(context, itemIndex);
                  }
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
