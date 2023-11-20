import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/studio_debugger.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/box/box_layout.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/pull_to_refresh.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/pull_to_refresh_container.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble/screen_controller.dart';

import '../framework/view/data_scope_widget.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget._controller.itemTemplate != null) {
      // initial value maybe set before the screen rendered
      templatedDataList = widget._controller.itemTemplate!.initialValue;

      registerItemTemplate(context, widget._controller.itemTemplate!,
          evaluateInitialValue: true, onDataChanged: (List dataList) {
        setState(() {
          templatedDataList = dataList;
        });
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    widget.controller._bind(this);

    // children displayed first, followed by item template
    int itemCount = (widget._controller.children?.length ?? 0) +
        (templatedDataList?.length ?? 0);
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }
    int indexAdd = 0;
    if (widget._controller.showLoading) {
      indexAdd = widget._controller.loadingWidget != null ? 1 : 0;
    }

    Widget listView = flutter.ListView.separated(
        controller: widget._controller.scrollController,
        padding: widget._controller.padding ?? const EdgeInsets.all(0),
        scrollDirection: Axis.vertical,
        physics: widget._controller.onPullToRefresh != null
            ? const AlwaysScrollableScrollPhysics()
            : null,
        itemCount: itemCount + indexAdd,
        shrinkWrap: false,
        reverse: widget._controller.reverse,
        itemBuilder: (BuildContext context, int index) {
          _checkScrollEnd(context, index);

          final total = (widget._controller.children?.length ?? 0) +
              (templatedDataList?.length ?? 0);
          if (widget._controller.showLoading) {
            if (index == total && widget._controller.loadingWidget != null) {
              final loadingWidget =
                  widgetBuilder(context, widget._controller.loadingWidget);

              return loadingWidget ?? const flutter.CircularProgressIndicator();
            }
          } else if (indexAdd == 1 && index == total) {
            return const SizedBox.shrink();
          }

          // show childrenfocus
          Widget? itemWidget;
          if (widget._controller.children != null &&
              index < widget._controller.children!.length) {
            itemWidget = buildChild(widget._controller.children![index]);
          }
          // create widget from item template
          else if (templatedDataList != null &&
              widget._controller.itemTemplate != null) {
            itemWidget = buildWidgetForIndex(
                context,
                templatedDataList!,
                widget._controller.itemTemplate!,
                // templated widget should start at 0, need to offset chidlren length
                index - (widget._controller.children?.length ?? 0));
          }
          if (itemWidget != null) {
            return widget._controller.onItemTap == null
                ? itemWidget
                : flutter.InkWell(
                    onTap: () => _onItemTapped(index), child: itemWidget);
          }
          return const SizedBox.shrink();
        },
        separatorBuilder: (context, index) =>
            widget._controller.showSeparator == true
                ? flutter.Padding(
                    padding: widget._controller.separatorPadding ??
                        const EdgeInsets.all(0),
                    child: flutter.Divider(
                        color: widget._controller.separatorColor,
                        thickness:
                            widget._controller.separatorWidth?.toDouble()))
                : const SizedBox.shrink());

    if (StudioDebugger().debugMode) {
      listView = StudioDebugger()
          .assertScrollableHasBoundedHeightWrapper(listView, ListView.type);
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
      widget._controller.selectedItemIndex = index;
      //log("Changed to index $index");
      ScreenController().executeAction(context, widget._controller.onItemTap!);
      print(
          "The Selected index in data array of ListView is ${widget._controller.selectedItemIndex}");
    }
  }

  void _checkScrollEnd(BuildContext context, int index) {
    final totalItems = (widget._controller.children?.length ?? 0) +
        (templatedDataList?.length ?? 0);
    if (index == totalItems - 1 && widget._controller.onScrollEnd != null) {
      ScreenController()
          .executeAction(context, widget._controller.onScrollEnd!);
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
