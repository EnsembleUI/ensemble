import 'dart:collection';
import 'dart:developer';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Layout items in a tile in a responsive fashion
class TileView extends StatefulWidget with UpdatableContainer, Invokable, HasController<TileViewController, TileViewState> {
  static const type = 'TileView';
  TileView({super.key});

  final TileViewController _controller = TileViewController();
  @override
  get controller => _controller;

  @override
  State<StatefulWidget> createState() => TileViewState();

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
      'onItemTap': (funcDefinition) => _controller.onItemTap =
          Utils.getAction(funcDefinition, initiator: this),
    };
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.itemTemplate = itemTemplate;
  }

}

class TileViewController extends BoxController {
  ItemTemplate? itemTemplate;
  EnsembleAction? onItemTap;
}
class TileViewState extends WidgetState<TileView> with TemplatedWidgetState {
  List _items = [];
  var _itemCaches = SplayTreeMap<int, Widget>();

  TileViewState() {
    log("Created TileViewState $hashCode");
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    log("didChangeDependencies");
    if (widget._controller.itemTemplate != null) {
      registerItemTemplate(
          context,
          widget._controller.itemTemplate!,
          evaluateInitialValue: true,
          onDataChanged: (List dataList) {
            setState(() {
              _items = dataList;
              _itemCaches = SplayTreeMap<int, Widget>();
            });
          });
    }
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
        widget: LayoutBuilder(builder: (context, constraints) {
          int horizontalTileCount = 1;
          if (constraints.maxWidth > 1600) {
            horizontalTileCount = 4;
          } else if (constraints.maxWidth > 1000) {
            horizontalTileCount = 3;
          } else if (constraints.maxWidth > 600) {
            horizontalTileCount = 2;
          }

          return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: horizontalTileCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 40,
                  childAspectRatio: 1.5
                  //mainAxisExtent: 250
              ),
              itemCount: _items.length,
              scrollDirection: Axis.vertical,
              padding: widget._controller.padding,
              itemBuilder: (context, index) {
                // if (_itemCaches[index] == null) {
                //   Widget? itemWidget = buildWidgetForIndex(
                //       context, _items, widget._controller.itemTemplate!, index);
                //   _itemCaches[index] = itemWidget ?? const SizedBox.shrink();
                // } {
                //   log("from cache ${_itemCaches[index]!.key?.toString()}");
                // }
                // return _itemCaches[index];
                return buildWidgetForIndex(
                          context, _items, widget._controller.itemTemplate!, index);
              });
        }));

  }


}