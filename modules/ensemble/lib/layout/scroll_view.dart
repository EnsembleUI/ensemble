import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/event.dart';

class ScrollView extends StatefulWidget
    with
        Invokable,
        HasItemTemplate,
        HasController<ScrollViewController, ScrollViewState> {
  static const type = 'ScrollView';
  static final defaultDuration = const Duration(milliseconds: 300);
  static final defaultCurve = Curves.fastOutSlowIn;

  final ScrollViewController _controller = ScrollViewController();

  @override
  ScrollViewController get controller => _controller;

  @override
  State<StatefulWidget> createState() => ScrollViewState();

  @override
  Map<String, Function> setters() => {
        'viewportFraction': (value) => _controller.viewportFraction =
            Utils.optionalDouble(value, min: 0.0, max: 1.0),
        'initialIndex': (value) =>
            _controller.initialIndex = Utils.optionalInt(value),
        'direction': (value) => _controller.direction = Axis.values.from(value),
        'padEnds': (value) => _controller.padEnds = Utils.optionalBool(value),
        'enableSnap': (value) =>
            _controller.enableSnap = Utils.optionalBool(value),
        'enableScrollGesture': (value) =>
            _controller.enableScrollGesture = Utils.optionalBool(value),
        'onItemTap': (def) =>
            _controller.onItemTap = EnsembleAction.from(def, initiator: this),
        'onItemLongPress': (def) => _controller.onItemLongPress =
            EnsembleAction.from(def, initiator: this),
      };

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() => {
        'next': () => controller.pageController
            ?.nextPage(duration: defaultDuration, curve: defaultCurve),
        'previous': () => controller.pageController
            ?.previousPage(duration: defaultDuration, curve: defaultCurve),
        'jumpTo': (index) {
          if (index is int) {
            controller.pageController?.jumpToPage(index);
          }
        },
        'animateTo': (index) {
          if (index is int) {
            controller.pageController?.animateToPage(index,
                duration: defaultDuration, curve: defaultCurve);
          }
        },
      };

  @override
  void setItemTemplate(Map itemTemplate) {
    _controller.itemTemplate = ItemTemplate.from(itemTemplate);
  }
}

class ScrollViewController extends BoxController {
  ItemTemplate? itemTemplate;

  Axis? direction;
  EnsembleAction? onItemTap;
  EnsembleAction? onItemLongPress;

  bool? padEnds;
  bool? enableSnap;
  bool? enableScrollGesture;

  // this is State but we have to put it here as it can be replaced at any time
  // when viewportFraction or initialIndex is updated.
  PageController? pageController;

  double _viewportFraction = 1.0;
  int _initialIndex = 0;

  set viewportFraction(double? num) {
    _viewportFraction = num ?? 1.0;
    resetPageController();
  }

  set initialIndex(int? index) {
    _initialIndex = index ?? 0;
    resetPageController();
  }

  /// call to replace the Page Controller when needed
  void resetPageController() {
    pageController?.dispose();
    pageController = PageController(
        viewportFraction: _viewportFraction, initialPage: _initialIndex);
  }
}

class ScrollViewState extends EWidgetState<ScrollView>
    with TemplatedWidgetState {
  List templatedData = [];

  @override
  void initState() {
    super.initState();
    // initialize pageController the first time
    if (widget._controller.pageController == null) {
      widget._controller.resetPageController();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget._controller.itemTemplate != null) {
      // initial value maybe set before the screen rendered
      templatedData =
          Utils.getList(widget._controller.itemTemplate!.initialValue) ?? [];
      registerItemTemplate(context, widget._controller.itemTemplate!,
          onDataChanged: (List dataList) {
        if (!mounted) return;

        setState(() {
          templatedData = dataList;
        });
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    final scopeManager = DataScopeWidget.getScope(context);
    if (widget._controller.itemTemplate == null ||
        templatedData.isEmpty ||
        scopeManager == null) {
      return SizedBox.shrink();
    }
    Widget rtn = PageView.builder(
        controller: widget._controller.pageController,
        scrollDirection: widget._controller.direction ?? Axis.horizontal,
        padEnds: widget._controller.padEnds ?? false,
        pageSnapping: widget._controller.enableSnap ?? true,
        // set to null to use scroll physics differently on different platform
        physics: widget._controller.enableScrollGesture == false ? NeverScrollableScrollPhysics() : null,
        itemCount: templatedData.length,
        itemBuilder: (context, index) => GestureDetector(
              onTap: widget._controller.onItemTap != null
                  ? () => _executeAction(widget._controller.onItemTap!, index)
                  : null,
              onLongPress: widget._controller.onItemLongPress != null
                  ? () =>
                      _executeAction(widget._controller.onItemLongPress!, index)
                  : null,
              child: buildSingleWidget(scopeManager,
                  widget._controller.itemTemplate!, templatedData[index]),
            ));
    return BoxWrapper(widget: rtn, boxController: widget._controller);
  }

  _executeAction(EnsembleAction action, int index) {
    ScreenController().executeAction(context, action,
        event: EnsembleEvent(widget, data: {"index": index}));
  }
}
