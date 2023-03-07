import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/layout_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/theme_manager.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' as flutter;
import 'package:ensemble/util/platform.dart';
import 'package:flutter/material.dart';

import '../widget/helpers/controllers.dart';

class Column extends BoxLayout {
  static const type = 'Column';
  Column({Key? key}) : super(key: key);

  @override
  bool isVertical() {
    return true;
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
      'direction': (value) => _controller.direction = Utils.optionalString(value)
    });
    return entries;
  }

  @override
  Map<String, Function> getters() {
    Map<String, Function> entries = super.getters();
    entries.addAll({
      'direction': () => _controller.direction
    });
    return entries;
  }

  @override
  bool isVertical() {
    return _controller.direction != 'horizontal';
  }
}


abstract class BoxLayout extends StatefulWidget with UpdatableContainer, Invokable, HasController<BoxLayoutController, BoxLayoutState> {
  BoxLayout({Key? key}) : super(key: key);

  late final ItemTemplate? itemTemplate;

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
      'onTap': (funcDefinition) => _controller.onTap = Utils.getAction(funcDefinition, initiator: this),
    };
  }
  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  void initChildren({List<Widget>? children, ItemTemplate? itemTemplate}) {
    _controller.children = children;
    this.itemTemplate = itemTemplate;
  }

  @override
  State<StatefulWidget> createState() => BoxLayoutState();

  bool isVertical();

}

/// base controller for Column/Row
class BoxLayoutController extends BoxController {
  EnsembleAction? onTap;

  bool scrollable = false;
  bool autoFit = false;
  String? mainAxis;
  String? crossAxis;
  String? mainAxisSize;
  int? maxWidth;
  int? maxHeight;
  int? gap;

  String? fontFamily;
  int? fontSize;

  List<Widget>? children;

  // applicable to Flex container only
  String? direction;
  // applicable only for ListView
  EnsembleAction? onItemTap;
  Color? sepratorColor;
  double? sepratorWidth;
  EdgeInsets? sepratorPadding;
  int selectedItemIndex= -1;


  @override
  Map<String, Function> getBaseSetters() {
    Map<String, Function> setters = super.getBaseSetters();
    setters.addAll({
      'scrollable': (value) => scrollable = Utils.getBool(value, fallback: false),
      'autoFit': (value) =>  autoFit = Utils.getBool(value, fallback: false),
      'mainAxis': (value) => mainAxis = Utils.optionalString(value),
      'crossAxis': (value) => crossAxis = Utils.optionalString(value),
      'mainAxisSize': (value) => mainAxisSize = Utils.optionalString(value),
      'maxWidth': (value) => maxWidth = Utils.optionalInt(value),
      'maxHeight': (value) => maxHeight = Utils.optionalInt(value),
      'gap': (value) => gap = Utils.optionalInt(value),

      'fontFamily': (value) => fontFamily = Utils.optionalString(value),
      'fontSize': (value) =>  fontSize = Utils.optionalInt(value),

    });
    return setters;
  }
}

class BoxLayoutState extends WidgetState<BoxLayout> with TemplatedWidgetState {
  List<Widget>? templatedChildren;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (widget.itemTemplate != null) {
      // initial value maybe set before the screen rendered
      if (widget.itemTemplate!.initialValue != null) {
        templatedChildren = buildWidgetsFromTemplate(context, widget.itemTemplate!.initialValue!, widget.itemTemplate!);
      }

      // listen for changes
      // Note that when visibility is toggled after rendering, the API may already be populated.
      // In that case we want to evaluate the data to see if they are there
      registerItemTemplate(context, widget.itemTemplate!, evaluateInitialValue: true, onDataChanged: (List dataList) {
        setState(() {
          templatedChildren = buildWidgetsFromTemplate(context, dataList, widget.itemTemplate!);
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

    // children will be rendered before templated children
    List<Widget> children = [];
    if (widget._controller.children != null) {
      children.addAll(widget._controller.children!);
    }
    if (templatedChildren != null) {
      children.addAll(templatedChildren!);
    }

    // if gap is specified, insert SizeBox between children
    if (widget._controller.gap != null) {
      Widget gapWidget = widget.isVertical() ?
        SizedBox(height: widget._controller.gap!.toDouble()) :
        SizedBox(width: widget._controller.gap!.toDouble());

      List<Widget> updatedChildren = [];
      for (var i=0; i<children.length; i++) {
        updatedChildren.add(children[i]);
        if (i != children.length-1) {
          updatedChildren.add(gapWidget);
        }
      }
      children = updatedChildren;
    }

    Widget boxWidget = _buildBoxWidget(children);

    // when we have a child (e.g Divider) that doesn't have an explicit size but stretches to
    // our container (Row/Column/Flex), our container needs to have an explicit size.
    // autoFit will explicitly size our container to the largest child, such that other
    // children like Divider can stretch across.
    // Note that this is in regard to the crossAxis (i.e Column needs to set its intrinsic width)
    if (widget._controller.autoFit) {
      boxWidget = widget.isVertical() ?
        IntrinsicWidth(child: boxWidget) :
        IntrinsicHeight(child: boxWidget);
    }


    Widget rtn = BoxWrapper(
        boxController: widget._controller,
        widget: boxWidget,
        ignoresMargin: true,
    );


     if (widget._controller.onTap != null) {
      rtn = flutter.InkWell(
        splashColor: Colors.transparent,
        child: rtn,
        onTap: () =>  ScreenController().executeAction(context, widget._controller.onTap!),
      );
    }
    
    
    if (widget._controller.margin != null) {
      rtn = Padding(
          padding: widget._controller.margin!,
          child: rtn);
    }

    return !widget._controller.scrollable ?
        rtn :
        SingleChildScrollView(
            scrollDirection: widget.isVertical() ? Axis.vertical : Axis.horizontal,
            child: rtn);

  }

  Widget _buildBoxWidget(List<Widget> children) {
    MainAxisAlignment mainAxis = widget._controller.mainAxis != null ?
      LayoutUtils.getMainAxisAlignment(widget._controller.mainAxis!) :
      MainAxisAlignment.start;

    CrossAxisAlignment crossAxis = widget._controller.crossAxis != null ?
      LayoutUtils.getCrossAxisAlignment(widget._controller.crossAxis!) :
      CrossAxisAlignment.start;

    MainAxisSize mainAxisSize = widget._controller.mainAxisSize == 'min' ?
      MainAxisSize.min :
      MainAxisSize.max;

    Widget boxWidget;
    if (widget is Column) {
      // wrapping SingleChildScrollView around a Column has performance issue in HTML renderer.
      // Now if we nested a non-scrollable ListView (render all items) inside the Column inside
      // the scrollable, then performance is better.
      if (widget._controller.scrollable && kIsWeb) {
        children = [
          ListView(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            children: children,
          )
        ];
      }
      boxWidget = flutter.Column(
          mainAxisAlignment: mainAxis,
          crossAxisAlignment: crossAxis,
          mainAxisSize: mainAxisSize,
          children: children);
    } else if (widget is Row) {
      boxWidget = flutter.Row(
          mainAxisAlignment: mainAxis,
          crossAxisAlignment: crossAxis,
          mainAxisSize: mainAxisSize,
          children: children);
    } else if (widget is Flex) {
      boxWidget = flutter.Flex(
          direction: widget.isVertical() ? Axis.vertical : Axis.horizontal,
          mainAxisAlignment: mainAxis,
          crossAxisAlignment: crossAxis,
          mainAxisSize: mainAxisSize,
          children: children);
    } else {
      boxWidget = const Text('Unsupported Box Layout');
    }

    // propagate text styling to all its children
    return DefaultTextStyle.merge(
        style: TextStyle(
          fontFamily: widget._controller.fontFamily,
          fontSize: widget._controller.fontSize != null ? widget._controller.fontSize!.toDouble() : null
        ),
        child: boxWidget);

  }

}
