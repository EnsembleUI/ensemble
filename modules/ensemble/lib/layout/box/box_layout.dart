import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/studio/studio_debugger.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/pull_to_refresh.dart';
import 'package:ensemble/model/shared_models.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/pull_to_refresh_container.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:flutter/material.dart';
import 'box_utils.dart';

class Column extends BoxLayout {
  static const type = 'Column';

  Column({Key? key}) : super(key: key);

  @override
  bool isVertical() {
    return true;
  }

  @override
  Map<String, Function> setters() {
    Map<String, Function> entries = super.setters();
    entries.addAll({
      'pullToRefresh': (input) =>
          _controller.pullToRefresh = PullToRefresh.fromMap(input, this),
      'onPullToRefresh': (funcDefinition) => _controller.onPullToRefresh =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'pullToRefreshOptions': (input) => _controller.pullToRefreshOptions =
          PullToRefreshOptions.fromMap(input),
    });
    return entries;
  }
}

class Row extends BoxLayout {
  static const type = 'Row';

  Row({Key? key}) : super(key: key);

  @override
  bool isVertical() {
    return false;
  }
}

class Flex extends BoxLayout {
  static const type = 'Flex';

  Flex({Key? key}) : super(key: key);

  @override
  Map<String, Function> setters() {
    Map<String, Function> entries = super.setters();
    entries.addAll({
      'direction': (value) =>
          _controller.direction = Utils.optionalString(value)
    });
    return entries;
  }

  @override
  Map<String, Function> getters() {
    Map<String, Function> entries = super.getters();
    entries.addAll({'direction': () => _controller.direction});
    return entries;
  }

  @override
  bool isVertical() {
    return _controller.direction != 'horizontal';
  }
}

abstract class BoxLayout extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<BoxLayoutController, BoxLayoutState> {
  BoxLayout({Key? key}) : super(key: key);

  final BoxLayoutController _controller = BoxLayoutController();

  @override
  BoxLayoutController get controller => _controller;

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'onTap': (funcDefinition) => _controller.onTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
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
  State<StatefulWidget> createState() => BoxLayoutState();

  bool isVertical();
}

class BoxLayoutState extends WidgetState<BoxLayout>
    with TemplatedWidgetState, HasChildren<BoxLayout> {
  List<Widget>? templatedChildren;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget._controller.itemTemplate != null) {
      // initial value maybe set before the screen rendered
      if (widget._controller.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(
            context,
            widget._controller.itemTemplate!.initialValue!,
            widget._controller.itemTemplate!);
      }

      // listen for changes
      // Note that when visibility is toggled after rendering, the API may already be populated.
      // In that case we want to evaluate the data to see if they are there
      registerItemTemplate(context, widget._controller.itemTemplate!,
          evaluateInitialValue: true, onDataChanged: (List dataList) {
        if (!mounted) return;
        setState(() {
          templatedChildren = buildWidgetsFromTemplate(
              context, dataList, widget._controller.itemTemplate!);
        });
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    templatedChildren = null;
  }

  @override
  Widget buildWidget(BuildContext context) {
    List<Widget>? childrenList = widget._controller.children != null
        ? buildChildren(widget._controller.children!)
        : null;
    List<Widget>? templatedList = templatedChildren;

    if (widget._controller.onItemTap != null) {
      childrenList = ViewUtil.addGesture(childrenList ?? [], _onItemTap);
      templatedList = ViewUtil.addGesture(templatedList ?? [], _onItemTap);
    }

    List<Widget> items = BoxUtils.buildChildrenAndGap(widget._controller.gap,
        children: childrenList, templatedChildren: templatedList);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    Widget boxWidget;
    if (widget is Column) {
      // wrapping SingleChildScrollView around a Column has performance issue in HTML renderer.
      // Now if we nested a non-scrollable ListView (render all items) inside the Column inside
      // the scrollable, then performance is better.
      if (widget._controller.scrollable && kIsWeb) {
        items = [
          ListView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: items,
          )
        ];
      }
      boxWidget = flutter.Column(
          mainAxisSize: widget._controller.mainAxisSize,
          mainAxisAlignment: widget._controller.mainAxis,
          crossAxisAlignment: widget._controller.crossAxis,
          children: items);
      if (StudioDebugger().debugMode) {
        boxWidget = RequiresRowColumnFlexWidget(child: boxWidget);
      }
    } else if (widget is Row) {
      boxWidget = flutter.Row(
          mainAxisSize: widget._controller.mainAxisSize,
          mainAxisAlignment: widget._controller.mainAxis,
          crossAxisAlignment: widget._controller.crossAxis,
          children: items);
      if (StudioDebugger().debugMode) {
        boxWidget = RequiresRowColumnFlexWidget(child: boxWidget);
      }
    } else if (widget is Flex) {
      boxWidget = flutter.Flex(
          direction: widget.isVertical() ? Axis.vertical : Axis.horizontal,
          mainAxisSize: widget._controller.mainAxisSize,
          mainAxisAlignment: widget._controller.mainAxis,
          crossAxisAlignment: widget._controller.crossAxis,
          children: items);
      if (StudioDebugger().debugMode) {
        boxWidget = RequiresRowColumnFlexWidget(child: boxWidget);
      }
    } else {
      throw LanguageError(
          "Invalid box widget. Column, Row, or Flex is required.");
    }

    // Row/Column does pass the crossAxis's constraint down, but only if it receives it from its parent.
    // When it doesn't, e.g. VerticalDivider inside Row inside a Column, all children HAS to be able to
    // calculate its own height otherwise it won't show up in the Row.
    // This property is an expensive operation, but it will calculate the constraint from the largest child
    // (that is at least 1 child has to have a size), and pass it down to all children.
    if (widget._controller.crossAxisConstraint ==
        CrossAxisConstraint.largestChild) {
      boxWidget = widget.isVertical()
          ? IntrinsicWidth(child: boxWidget)
          : IntrinsicHeight(child: boxWidget);
    }

    // when we have a child (e.g Divider) that doesn't have an explicit size but stretches to
    // our container (Row/Column/Flex), our container needs to have an explicit size.
    // autoFit will explicitly size our container to the largest child, such that other
    // children like Divider can stretch across.
    // Note that this is in regard to the crossAxis (i.e Column needs to set its intrinsic width)
    // if (widget._controller.autoFit) {
    //   boxWidget = widget.isVertical()
    //       ? IntrinsicWidth(child: boxWidget)
    //       : IntrinsicHeight(child: boxWidget);
    // }

    Widget rtn = BoxLayoutWrapper(
        boxWidget: boxWidget,
        controller: widget._controller,
        ignoresMargin: widget is Column);

    var pullToRefresh = _getPullToRefresh();
    if (widget._controller.scrollable || pullToRefresh != null) {
      FooterScope? footerScope = FooterScope.of(context);
      rtn = ScrollableColumn(
        child: SingleChildScrollView(
            controller: (widget.isVertical() &&
                    footerScope != null &&
                    footerScope.isRootWithinFooter(context))
                ? FooterScope.of(context)!.scrollController
                : null,
            scrollDirection:
                widget.isVertical() ? Axis.vertical : Axis.horizontal,
            physics: pullToRefresh != null
                ? const AlwaysScrollableScrollPhysics()
                : null,
            child: rtn),
      );

      if (widget is Column && pullToRefresh != null) {
        rtn =
            PullToRefreshContainer(options: pullToRefresh, contentWidget: rtn);
      }
    }

    // for Column we add margin at the end, just in case it is inside a Scrollable or PullToRefresh
    if (widget is Column && widget._controller.margin != null) {
      rtn = Padding(padding: widget._controller.margin!, child: rtn);
    }

    return rtn;
  }

  // backward compatible
  PullToRefresh? _getPullToRefresh() {
    return widget._controller.pullToRefresh ??
        (widget._controller.onPullToRefresh != null
            ? PullToRefresh(
                widget._controller.onPullToRefresh!,
                indicatorType:
                    widget._controller.pullToRefreshOptions?.indicatorType,
                indicatorMinDuration: widget
                    ._controller.pullToRefreshOptions?.indicatorMinDuration,
                indicatorPadding:
                    widget._controller.pullToRefreshOptions?.indicatorPadding,
              )
            : null);
  }

  void _onItemTap(int index) {
    if (widget.controller.onItemTap != null) {
      ScreenController().executeAction(
        context,
        widget._controller.onItemTap!,
        event: EnsembleEvent(widget, data: {'selectedItemIndex': index}),
      );
    }
  }
}

class ScrollableColumn extends flutter.InheritedWidget {
  const ScrollableColumn({super.key, required super.child});

  static ScrollableColumn? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ScrollableColumn>();

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}
