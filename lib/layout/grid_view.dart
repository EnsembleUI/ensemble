import 'dart:collection';
import 'dart:developer';

import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/studio_debugger.dart';
import 'package:ensemble/framework/view/footer.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/pull_to_refresh.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/util/gesture_detector.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/framework/theme/theme_manager.dart';
import 'package:ensemble/widget/helpers/pull_to_refresh_container.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as flutter;

/// Layout items in a tile in a responsive fashion
class GridView extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<GridViewController, GridViewState> {
  static const type = 'GridView';

  GridView({super.key});

  final GridViewController _controller = GridViewController();

  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => GridViewState();

  @override
  Map<String, Function> getters() {
    return {
      'selectedItemIndex': () => _controller.selectedItemIndex,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {
      'horizontalTileCount': (value) =>
          _controller.setHorizontalTileCount(value),
      'horizontalGap': (value) =>
          _controller.horizontalGap = Utils.optionalInt(value, min: 0),
      'verticalGap': (value) =>
          _controller.verticalGap = Utils.optionalInt(value, min: 0),
      'itemHeight': (value) =>
          _controller.itemHeight = Utils.optionalInt(value, min: 0),
      'itemAspectRatio': (value) =>
          _controller.itemAspectRatio = Utils.optionalDouble(value, min: 0),
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'onItemTapHaptic': (value) =>
          _controller.onItemTapHaptic = Utils.optionalString(value),
      'onPullToRefresh': (funcDefinition) => _controller.onPullToRefresh =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'pullToRefreshOptions': (input) => _controller.pullToRefreshOptions =
          PullToRefreshOptions.fromMap(input),
      'onScrollEnd': (funcDefinition) => _controller.onScrollEnd =
          EnsembleAction.fromYaml(funcDefinition, initiator: this),
      'reverse': (value) =>
          _controller.reverse = Utils.getBool(value, fallback: false),
      'scrollController': (value) {
        if (value is! ScrollController) return null;
        return _controller.scrollController = value;
      },
      'direction': (value) =>
          _controller.direction = Utils.optionalString(value),
    };
  }

  @override
  void initChildren({List<WidgetModel>? children, ItemTemplate? itemTemplate}) {
    _controller.itemTemplate = itemTemplate;
  }
}

class GridViewController extends BoxController with HasPullToRefresh {
  List<int>? horizontalTileCount;
  int? horizontalGap;
  int? verticalGap;

  int? itemHeight;
  double? itemAspectRatio;

  ItemTemplate? itemTemplate;
  EnsembleAction? onItemTap;
  String? onItemTapHaptic;
  int selectedItemIndex = -1;
  EnsembleAction? onScrollEnd;
  bool reverse = false;
  ScrollController? scrollController;
  String? direction;

  // single number, 3 numbers (small, medium, large), or 5 numbers (xSmall, small, medium, large, xLarge)
  // min 1, max 5
  setHorizontalTileCount(dynamic value) {
    if (value is int) {
      int? val = Utils.optionalInt(value, min: 1, max: 5);
      if (val != null) {
        horizontalTileCount = [value];
      }
    } else if (value is String) {
      List<int> values = Utils.stringToIntegers(value, min: 1, max: 5);
      if (values.length == 1 || values.length == 3 || values.length == 5) {
        (horizontalTileCount ??= []).addAll(values);
      }
    }
  }
}

class GridViewState extends WidgetState<GridView> with TemplatedWidgetState {
  static const gap = 10.0;
  static const cachedPixels = 500.0; // cache an additional iphone size height

  List _items = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(context, widget._controller.itemTemplate!,
          evaluateInitialValue: true, onDataChanged: (List dataList) {
        setState(() {
          _items = dataList;
        });
      });
    }
  }

  /// get the horizontal tile count depending on the screen size
  /// or what the user enters
  int _getTileCount(BoxConstraints constraints) {
    List<int>? tileCount = widget._controller.horizontalTileCount;
    // auto determine the tile count if not specified
    if (tileCount == null) {
      if (constraints.isXLarge()) {
        return 4;
      } else if (constraints.isLarge()) {
        return 3;
      } else if (constraints.isMedium()) {
        return 2;
      } else {
        return 1;
      }
    } else {
      // only 1 number specified -> same number for all screen sizes
      if (tileCount.length == 1) {
        return tileCount[0];
      }
      // three numbers = small / medium / large
      else if (tileCount.length == 3) {
        if (constraints.isSmallOrLess()) {
          return tileCount[0];
        } else if (constraints.isLargeOrMore()) {
          return tileCount[2];
        }
        // medium
        return tileCount[1];
      }
      // five numbers = xSmall / small / medium / large / xLarge
      else if (tileCount.length == 5) {
        if (constraints.isXSmall()) {
          return tileCount[0];
        } else if (constraints.isSmall()) {
          return tileCount[1];
        } else if (constraints.isLarge()) {
          return tileCount[3];
        } else if (constraints.isXLarge()) {
          return tileCount[4];
        }
        // medium
        return tileCount[2];
      }
    }
    throw LanguageError(
        "horizontalTileCount has to be a single number, three numbers (for small, medium, large breakpoints), or five numbers (xSmall, small, medium, large, xLarge. Each number has to be from 1 to 5.");
  }

  @override
  Widget buildWidget(BuildContext context) {
    FooterScope? footerScope = FooterScope.of(context);
    if (footerScope != null && footerScope.isRootWithinFooter(context)) {
      widget._controller.scrollController = footerScope.scrollController;
    }
    if (widget._controller.itemTemplate == null) {
      return const SizedBox.shrink();
    }

    Widget myGridView = LayoutBuilder(builder: (context, constraints) {
      return flutter.GridView.builder(
          controller: (footerScope != null &&
                  footerScope.isColumnScrollableAndRoot(context))
              ? null
              : widget._controller.scrollController,
          shrinkWrap: FooterScope.of(context) != null ? true : false,
          physics: (footerScope != null &&
                  footerScope.isColumnScrollableAndRoot(context))
              ? const NeverScrollableScrollPhysics()
              : widget._controller.onPullToRefresh != null
                  ? const AlwaysScrollableScrollPhysics()
                  : null,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _getTileCount(constraints),
            crossAxisSpacing:
                widget._controller.horizontalGap?.toDouble() ?? gap,
            mainAxisSpacing: widget._controller.verticalGap?.toDouble() ?? gap,

            // itemHeight take precedent, then itemAspectRatio
            mainAxisExtent: widget._controller.itemHeight?.toDouble(),
            childAspectRatio:
                widget._controller.itemAspectRatio?.toDouble() ?? 1.0,
          ),
          itemCount: _items.length,
          reverse: widget._controller.reverse,
          scrollDirection: widget._controller.direction == 'horizontal'
              ? flutter.Axis.horizontal
              : flutter.Axis.vertical,
          cacheExtent: cachedPixels,
          padding: widget._controller.padding,
          itemBuilder: (context, index) => _buildItem(index));
    });
    if (StudioDebugger().debugMode) {
      myGridView = StudioDebugger().assertScrollableHasBoundedHeightWrapper(
          myGridView, GridView.type, context, widget.controller);
    }
    // wrapping view inside

    if (widget._controller.onPullToRefresh != null) {
      myGridView = PullToRefreshContainer(
          options: widget._controller.pullToRefreshOptions,
          onRefresh: _pullToRefresh,
          contentWidget: myGridView);
    }

    return BoxWrapper(
      boxController: widget._controller,
      // we handle padding in the GridView so the scrollbar doesn't overlap content
      ignoresPadding: true,
      widget: myGridView,
    );
  }

  Future<void> _pullToRefresh() async {
    if (widget._controller.onPullToRefresh != null) {
      await ScreenController()
          .executeAction(context, widget._controller.onPullToRefresh!);
    }
  }

  dynamic _buildItem(int index) {
    if (index == _items.length - 1 && widget._controller.onScrollEnd != null) {
      ScreenController()
          .executeAction(context, widget._controller.onScrollEnd!);
    }
    if (widget._controller.onItemTap != null) {
      return EnsembleGestureDetector(
        onTap: (() => _onItemTap(index)),
        child: buildWidgetForIndex(
            context, _items, widget._controller.itemTemplate!, index),
      );
    }
    return buildWidgetForIndex(
        context, _items, widget._controller.itemTemplate!, index);
  }

  void _onItemTap(int index) {
    if (widget.controller.onItemTap != null) {
      if (widget.controller.onItemTapHaptic != null) {
        ScreenController().executeAction(
          context,
          HapticAction(
            type: widget.controller.onItemTapHaptic!,
            onComplete: null,
          ),
        );
      }

      widget._controller.selectedItemIndex = index;
      ScreenController().executeAction(context, widget._controller.onItemTap!);
    }
  }
}
