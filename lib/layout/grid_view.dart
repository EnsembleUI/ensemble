import 'dart:collection';
import 'dart:developer';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/theme_manager.dart';
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
    return {};
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
          Utils.getAction(funcDefinition, initiator: this),
    };
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.itemTemplate = itemTemplate;
  }

}

class GridViewController extends BoxController {
  List<int>? horizontalTileCount;
  int? horizontalGap;
  int? verticalGap;

  int? itemHeight;
  double? itemAspectRatio;

  ItemTemplate? itemTemplate;
  EnsembleAction? onItemTap;

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
      registerItemTemplate(
          context,
          widget._controller.itemTemplate!,
          evaluateInitialValue: true,
          onDataChanged: (List dataList) {
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
    }
    else {
      // only 1 number specified -> same number for all screen sizes
      if (tileCount.length == 1) {
        return tileCount[0];
      }
      // three numbers = small / medium / large
      else if (tileCount.length == 3) {
        if (constraints.isSmallOrLess()) {
          return tileCount[0];
        }
        if (constraints.isMedium()) {
          return tileCount[1];
        }
        if (constraints.isLargeOrMore()) {
          return tileCount[2];
        }
      }
      // five numbers = xSmall / small / medium / large / xLarge
      else if (tileCount.length == 5) {
        if (constraints.isXSmall()) {
          return tileCount[0];
        }
        if (constraints.isSmall()) {
          return tileCount[1];
        }
        if (constraints.isMedium()) {
          return tileCount[2];
        }
        if (constraints.isLarge()) {
          return tileCount[3];
        }
        if (constraints.isXLarge()) {
          return tileCount[4];
        }
      }
    }
    throw LanguageError(
        "horizontalTileCount has to be a single number, three numbers (for small, medium, large breakpoints), or five numbers (xSmall, small, medium, large, xLarge. Each number has to be from 1 to 5.");
  }

  @override
  Widget buildWidget(BuildContext context) {
    if (widget._controller.itemTemplate == null) {
      return const SizedBox.shrink();
    }

    return BoxWrapper(
        boxController: widget._controller,
        // we handle padding in the GridView so the scrollbar doesn't overlap content
        ignoresPadding: true,
        widget: LayoutBuilder(builder: (context, constraints) =>
            flutter.GridView.builder(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _getTileCount(constraints),
                  crossAxisSpacing: widget._controller.horizontalGap
                      ?.toDouble() ?? gap,
                  mainAxisSpacing: widget._controller.verticalGap?.toDouble() ??
                      gap,

                  // itemHeight take precedent, then itemAspectRatio
                  mainAxisExtent: widget._controller.itemHeight?.toDouble(),
                  childAspectRatio: widget._controller.itemAspectRatio
                      ?.toDouble() ?? 1.0,

                ),
                itemCount: _items.length,
                scrollDirection: Axis.vertical,
                cacheExtent: cachedPixels,
                padding: widget._controller.padding,
                itemBuilder: (context, index) =>
                    buildWidgetForIndex(
                        context, _items, widget._controller.itemTemplate!,
                        index)))
    );
  }


}