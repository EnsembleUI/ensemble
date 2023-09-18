import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/box/base_box_layout.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/widget/carousel.dart';
import 'package:ensemble/widget/helpers/pull_to_refresh_container.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble/util/platform.dart';
import 'package:flutter/material.dart';

import '../../widget/helpers/controllers.dart';
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
      'onPullToRefresh': (funcDefinition) => _controller.onPullToRefresh =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'refreshIndicatorType': (value) => _controller.refreshIndicatorType =
          RefreshIndicatorType.values.from(value),
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
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    _controller.itemTemplate = itemTemplate;
  }

  @override
  State<StatefulWidget> createState() => BoxLayoutState();

  bool isVertical();
}

class BoxLayoutState extends WidgetState<BoxLayout> with TemplatedWidgetState {
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
    List<Widget>? childrenList = widget._controller.children;
    List<Widget>? templatedList = templatedChildren;

    if (widget._controller.onItemTap != null) {
      childrenList = ViewUtil.addGesture(childrenList ?? [], _onItemTap);
      templatedList = ViewUtil.addGesture(templatedList ?? [], _onItemTap);
    }

    List<Widget> items = BoxUtils.buildChildrenAndGap(widget._controller,
        children: childrenList, templatedChildren: templatedList);
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    // default to max but user can always change it to min
    MainAxisSize mainAxisSize = widget._controller.mainAxisSize == 'min'
        ? MainAxisSize.min
        : MainAxisSize.max;

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
          mainAxisSize: mainAxisSize,
          mainAxisAlignment: widget._controller.mainAxis,
          crossAxisAlignment: widget._controller.crossAxis,
          children: items);
    } else if (widget is Row) {
      boxWidget = flutter.Row(
          mainAxisSize: mainAxisSize,
          mainAxisAlignment: widget._controller.mainAxis,
          crossAxisAlignment: widget._controller.crossAxis,
          children: items);
    } else if (widget is Flex) {
      boxWidget = flutter.Flex(
          direction: widget.isVertical() ? Axis.vertical : Axis.horizontal,
          mainAxisSize: mainAxisSize,
          mainAxisAlignment: widget._controller.mainAxis,
          crossAxisAlignment: widget._controller.crossAxis,
          children: items);
    } else {
      throw LanguageError(
          "Invalid box widget. Column, Row, or Flex is required.");
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

    Widget rtn =
        BoxLayoutWrapper(boxWidget: boxWidget, controller: widget._controller);

    if (widget._controller.scrollable) {
      rtn = SingleChildScrollView(
          scrollDirection:
              widget.isVertical() ? Axis.vertical : Axis.horizontal,
          physics: widget._controller.onPullToRefresh != null
              ? const AlwaysScrollableScrollPhysics()
              : null,
          child: rtn);

      if (widget is Column && widget._controller.onPullToRefresh != null) {
        rtn = PullToRefreshContainer(
            indicatorType: widget._controller.refreshIndicatorType,
            contentWidget: rtn,
            onRefresh: _pullToRefresh);
      }
    }
    return rtn;
  }

  Future<void> _pullToRefresh() async {
    if (widget._controller.onPullToRefresh != null) {
      await ScreenController()
          .executeAction(context, widget._controller.onPullToRefresh!);
    }
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
