import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/studio_debugger.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/pull_to_refresh.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/pull_to_refresh_container.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

class ListView extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<ListViewController, BoxLayoutState> {
  static const type = 'ListView';

  ListView({Key? key}) : super(key: key);

  final ListViewController _controller = ListViewController();

  @override
  ListViewController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {
      'selectedItemIndex': () => _controller.selectedItemIndex,
      'data': () => _controller.widgetState?.templatedDataList,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onItemTapHaptic': (value) =>
          _controller.onItemTapHaptic = Utils.optionalString(value),
      'showSeparator': (value) =>
          _controller.showSeparator = Utils.optionalBool(value),
      'separatorColor': (value) =>
          _controller.separatorColor = Utils.getColor(value),
      'separatorWidth': (value) =>
          _controller.separatorWidth = Utils.optionalDouble(value),
      'separatorPadding': (value) =>
          _controller.separatorPadding = Utils.optionalInsets(value),
      'onPullToRefresh': (funcDefinition) => _controller.onPullToRefresh =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'pullToRefreshOptions': (input) => _controller.pullToRefreshOptions =
          PullToRefreshOptions.fromMap(input),
      'onScrollEnd': (funcDefinition) => _controller.onScrollEnd =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'reverse': (value) =>
          _controller.reverse = Utils.getBool(value, fallback: false),
      'controller': (value) {
        if (value is! ScrollController) return null;
        return _controller.scrollController = value;
      },
      'showLoading': (value) =>
          _controller.showLoading = Utils.getBool(value, fallback: false),
      'loadingWidget': (value) => _controller.loadingWidget = value,
      'data': (value) => _controller.itemTemplate?.data = value,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  void initChildren({List<WidgetModel>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    _controller.itemTemplate = itemTemplate;
  }

  @override
  State<StatefulWidget> createState() => ListViewState();
}

class ListViewController extends BoxLayoutController {
  int selectedItemIndex = -1;

  bool? showSeparator;
  Color? separatorColor;
  double? separatorWidth;
  EdgeInsets? separatorPadding;
  EnsembleAction? onScrollEnd;
  String? onItemTapHaptic;
  bool reverse = false;
  ScrollController? scrollController;
  dynamic loadingWidget;
  bool showLoading = false;
  ListViewState? widgetState;
  void _bind(ListViewState state) {
    widgetState = state;
  }
}

class ListViewState extends WidgetState<ListView>
    with TemplatedWidgetState, HasChildren<ListView> {
  // template item is created on scroll. this will store the template's data list
  List<dynamic>? templatedDataList;

  final PagingController<dynamic, dynamic> _pagingController =
      PagingController(firstPageKey: 0);
  bool? previousLoadingStatus;

  @override
  void initState() {
    initializePaginationController();
    super.initState();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    widget._controller.removeListener(listener);
    super.dispose();
  }

  void initializePaginationController() {
    _pagingController.addPageRequestListener((pageKey) {
      if (widget._controller.onScrollEnd != null) {
        ScreenController()
            .executeAction(context, widget._controller.onScrollEnd!);
      } else {
        _pagingController.appendLastPage([]);
      }
    });

    if (widget._controller.children?.isNotEmpty == true) {
      _pagingController.appendPage(widget._controller.children!, 1);
    }

    widget._controller.addListener(listener);
  }

  void listener() {
    if (previousLoadingStatus != widget._controller.showLoading) {
      if (widget._controller.showLoading == false) {
        _pagingController.appendLastPage([]);
      }
      previousLoadingStatus = widget._controller.showLoading;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget._controller.itemTemplate != null) {
      // initial value maybe set before the screen rendered
      templatedDataList = widget._controller.itemTemplate!.initialValue;

      registerItemTemplate(context, widget._controller.itemTemplate!,
          evaluateInitialValue: true, onDataChanged: (List dataList) {
        if (!mounted) return;

        setState(() {
          templatedDataList = dataList;
          _pagingController.appendPage(templatedDataList!, 'loadMore');
        });
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    widget.controller._bind(this);
    FooterScope? footerScope = FooterScope.of(context);
    if (footerScope != null && footerScope.isRootWithinFooter(context)) {
      widget._controller.scrollController = footerScope.scrollController;
    }
    Widget? loadingWidget;

    if (widget._controller.loadingWidget != null) {
      loadingWidget = widgetBuilder(context, widget._controller.loadingWidget);
    }

    Widget listView = PagedListView.separated(
      scrollController: (footerScope != null &&
              footerScope.isColumnScrollableAndRoot(context))
          ? null
          : widget._controller.scrollController,
      shrinkWrap: FooterScope.of(context) != null ? true : false,
      reverse: widget._controller.reverse,
      padding: widget._controller.padding ?? const EdgeInsets.all(0),
      physics: (footerScope != null &&
              footerScope.isColumnScrollableAndRoot(context))
          ? const NeverScrollableScrollPhysics()
          : widget._controller.onPullToRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : null,
      pagingController: _pagingController,
      builderDelegate: PagedChildBuilderDelegate(
        itemBuilder: (context, item, index) {
          Widget? itemWidget;
          if (widget._controller.children != null &&
              index < widget._controller.children!.length) {
            itemWidget = buildChild(widget._controller.children![index]);
          }
          // create widget from item template
          else if (templatedDataList != null &&
              widget._controller.itemTemplate != null) {
            final templateIndex =
                index - (widget._controller.children?.length ?? 0);
            if (templateIndex < templatedDataList!.length) {
              itemWidget = buildWidgetForIndex(
                context,
                templatedDataList!,
                widget._controller.itemTemplate!,
                // templated widget should start at 0, need to offset chidlren length
                templateIndex,
              );
            }
          }
          if (itemWidget != null) {
            return widget._controller.onItemTap == null
                ? itemWidget
                : flutter.InkWell(
                    onTap: () => _onItemTapped(index), child: itemWidget);
          }
          return const SizedBox.shrink();
        },
        newPageProgressIndicatorBuilder: (context) {
          return loadingWidget ?? const SizedBox.shrink();
        },
        noItemsFoundIndicatorBuilder: (context) => const SizedBox.shrink(),
        noMoreItemsIndicatorBuilder: (context) => const SizedBox.shrink(),
        firstPageErrorIndicatorBuilder: (context) => const SizedBox.shrink(),
        newPageErrorIndicatorBuilder: (context) => const SizedBox.shrink(),
      ),
      separatorBuilder: (context, index) =>
          widget._controller.showSeparator == true
              ? flutter.Padding(
                  padding: widget._controller.separatorPadding ??
                      const EdgeInsets.all(0),
                  child: flutter.Divider(
                      color: widget._controller.separatorColor,
                      thickness: widget._controller.separatorWidth?.toDouble()),
                )
              : const SizedBox.shrink(),
    );

    if (StudioDebugger().debugMode) {
      listView = StudioDebugger().assertScrollableHasBoundedHeightWrapper(
          listView, ListView.type, context, widget._controller);
    }

    if (widget._controller.onPullToRefresh != null) {
      listView = PullToRefreshContainer(
          options: widget._controller.pullToRefreshOptions,
          onRefresh: _pullToRefresh,
          contentWidget: listView);
    }

    return BoxWrapper(
        boxController: widget._controller,
        widget: DefaultTextStyle.merge(
            style: TextStyle(
                fontFamily: widget._controller.fontFamily,
                fontSize: widget._controller.fontSize?.toDouble()),
            child: listView));
  }

  Future<void> _pullToRefresh() async {
    if (widget._controller.onPullToRefresh != null) {
      await ScreenController()
          .executeAction(context, widget._controller.onPullToRefresh!);
    }
  }

  void _onItemTapped(int index) {
    if (index != widget._controller.selectedItemIndex &&
        widget._controller.onItemTap != null) {
      if (widget._controller.onItemTapHaptic != null) {
        ScreenController().executeAction(
          context,
          HapticAction(
            type: widget._controller.onItemTapHaptic!,
            onComplete: null,
          ),
        );
      }

      widget._controller.selectedItemIndex = index;
      //log("Changed to index $index");
      ScreenController().executeAction(context, widget._controller.onItemTap!);
      print(
          "The Selected index in data array of ListView is ${widget._controller.selectedItemIndex}");
    }
  }

  Widget? widgetBuilder(BuildContext context, dynamic widget) {
    ScopeManager? parentScope = DataScopeWidget.getScope(context);
    if (parentScope != null) {
      return parentScope.buildWidgetFromDefinition(widget);
    } else {
      LanguageError('Failed to build widget');
      return null;
    }
  }
}
