import 'package:ensemble/framework/widget/has_children.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/box_wrapper.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'package:ensemble/framework/action.dart' as action;
import 'package:yaml/yaml.dart';
import '../../layout/list_view.dart' as ensemblelistview;
import '../../layout/grid_view.dart' as ensemblegridview;
import '../../layout/box/box_layout.dart' as ensemblecolumn;
import 'dart:math' as math;

class Footer extends StatefulWidget
    with
        UpdatableContainer,
        Invokable,
        HasController<FooterController, _FooterState> {
  Footer({super.key});

  static const String type = "footer";

  @override
  State<Footer> createState() => _FooterState();

  @override
  FooterController get controller => _controller;

  final FooterController _controller = FooterController();

  @override
  Map<String, Function> getters() {
    return {"controller": () => controller.scrollBehavior};
  }

  @override
  Map<String, Function> methods() {
    return {
      'drag': handleDrag,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      "children": (value) =>
          _controller.dragableChildrenMap = Utils.getYamlMap(value),
      "dragOptions": (value) => _controller.dragOptions =
          DragOptions.fromYaml(Utils.getYamlMap(value) ?? YamlMap(), this)
    };
  }

  @override
  void initChildren({List<WidgetModel>? children, Map? itemTemplate}) {
    _controller.children = children;
  }

  void handleDrag(dynamic value) {
    final size = Utils.optionalDouble(value);
    if (size == null) return;
    _controller.dragController.animateTo(
      size,
      duration: const Duration(milliseconds: 250),
      curve: Curves.bounceIn,
    );
  }
}

class _FooterState extends EWidgetState<Footer>
    with HasChildren<Footer>, TemplatedWidgetState {
  DragOptions? _dragOptions;
  late DraggableScrollableController _dragController;

  @override
  void initState() {
    super.initState();
    _dragController = widget._controller.dragController;
    _dragOptions = widget.controller.dragOptions;
    if (_dragOptions != null) {
      _dragOptions = widget._controller.dragOptions!;
      _dragController.addListener(
        () {
          if (_dragController.size == _dragOptions?.maxSize &&
              _dragOptions?.onMaxSize != null) {
            ScreenController().executeAction(context, _dragOptions!.onMaxSize!);
          }
          if (_dragController.size == _dragOptions?.minSize &&
              _dragOptions?.onMinSize != null) {
            ScreenController().executeAction(context, _dragOptions!.onMinSize!);
          }
        },
      );
    }
  }

  @override
  void didUpdateWidget(covariant Footer oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget._controller.dragController = oldWidget._controller.dragController;
  }

  @override
  void dispose() {
    _dragController.dispose();
    super.dispose();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0,
      duration: const Duration(milliseconds: 250),
      child: (_dragOptions != null &&
              widget.controller.dragOptions!.isDraggable)
          ? DraggableScrollableSheet(
              controller: _dragController,
              initialChildSize: _dragOptions!.initialSize,
              minChildSize: _dragOptions!.minSize,
              maxChildSize: _dragOptions!.maxSize,
              expand: _dragOptions!.expand,
              snap: _dragOptions!.snap,
              snapSizes: _dragOptions!.snapSizes,
              builder:
                  (BuildContext context, ScrollController scrollController) {
                widget.controller.scrollBehavior = scrollController;
                Widget child = (widget.controller.children != null)
                    ? FooterScope(
                        dragOptions: _dragOptions!,
                        scrollController: scrollController,
                        child: (_dragOptions!.showDragHandle)
                            ? Stack(
                                alignment: Alignment.topCenter,
                                children: <Widget>[
                                  dragHandle(context),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        top: kMinInteractiveDimension),
                                    child: buildChildren(
                                            widget.controller.children!)
                                        .first,
                                  ),
                                ],
                              )
                            : buildChildren(widget.controller.children!).first)
                    : const SizedBox.shrink();
                return BoxWrapper(
                  boxController: widget.controller,
                  widget: child,
                );
              },
            )
          : BoxWrapper(
              boxController: widget.controller,
              widget: (widget.controller.children != null)
                  ? buildChildren(widget.controller.children!).first
                  : const SizedBox.shrink(),
            ),
    );
  }

  Widget dragHandle(BuildContext context) {
    ColorScheme colors = Theme.of(context).colorScheme;
    var handleSize = const Size(32, 4);
    return SizedBox(
      height: kMinInteractiveDimension,
      width: kMinInteractiveDimension,
      child: Center(
        child: Container(
          height: handleSize.height,
          width: handleSize.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(handleSize.height / 2),
            color: colors.onSurfaceVariant.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

class FooterController extends BoxController {
  YamlMap? dragableChildrenMap;
  List<WidgetModel>? dragableChildren;
  List<WidgetModel>? children;

  ScrollController? scrollBehavior;
  DragOptions? dragOptions;
  DraggableScrollableController dragController =
      DraggableScrollableController();
}

class DragOptions {
  action.EnsembleAction? onMaxSize;
  action.EnsembleAction? onMinSize;
  double maxSize;
  double minSize;
  bool isDraggable; // enable
  double initialSize;
  bool expand;
  bool snap;
  List<double>? snapSizes;
  bool showDragHandle = false;

  DragOptions(
      {required this.onMaxSize,
      required this.onMinSize,
      required this.maxSize,
      required this.minSize,
      required this.isDraggable,
      required this.initialSize,
      required this.expand,
      required this.snap,
      required this.showDragHandle,
      required this.snapSizes});

  factory DragOptions.fromYaml(YamlMap yamlMap, Invokable invokable) =>
      DragOptions(
          onMaxSize:
              action
                      .EnsembleAction
                  .from(yamlMap['onMaxSize'], initiator: invokable),
          onMinSize:
              action.EnsembleAction.from(yamlMap['onMinSize'],
                  initiator: invokable),
          minSize: Utils.getDouble(yamlMap['minSize'], fallback: 0.25),
          maxSize: Utils.getDouble(yamlMap['maxSize'], fallback: 1.0),
          isDraggable: Utils.getBool(yamlMap['enable'], fallback: false),
          initialSize: Utils.getDouble(yamlMap['initialSize'], fallback: 0.5),
          expand: Utils.getBool(yamlMap['expand'], fallback: false),
          snap: Utils.getBool(yamlMap, fallback: false),
          snapSizes: Utils.getList(yamlMap['snapSize']),
          showDragHandle:
              Utils.getBool(yamlMap['enableDragHandler'], fallback: false));
}

class FooterScope extends InheritedWidget {
  FooterScope(
      {super.key,
      required super.child,
      this.scrollController,
      this.rootWithinFooterFound = false,
      required this.dragOptions});

  final ScrollController? scrollController;
  final DragOptions dragOptions;
  bool rootWithinFooterFound;

  static FooterScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FooterScope>();

  bool isRootWithinFooter(BuildContext context) {
    if (rootWithinFooterFound) {
      return false;
    } else {
      if (FooterScope.of(context) != null &&
          FooterScope.of(context)!.dragOptions.isDraggable &&
          context.findAncestorWidgetOfExactType<
                  ensemblecolumn.ScrollableColumn>() ==
              null &&
          context.findAncestorWidgetOfExactType<ensemblegridview.GridView>() ==
              null &&
          context.findAncestorWidgetOfExactType<ensemblelistview.ListView>() ==
              null) {
        rootWithinFooterFound = true;
        return true;
      } else {
        return false;
      }
    }
  }

  bool isColumnScrollableAndRoot(BuildContext context) =>
      context
          .findAncestorWidgetOfExactType<ensemblecolumn.ScrollableColumn>() !=
      null;

  @override
  bool updateShouldNotify(covariant FooterScope oldWidget) =>
      oldWidget.scrollController == scrollController;
}

enum _FooterSlot { footer, body }

class _FooterLayout extends MultiChildLayoutDelegate {
  final EdgeInsets minInsets;

  _FooterLayout({required this.minInsets});

  @override
  void performLayout(Size size) {
    final BoxConstraints looseConstraints = BoxConstraints.loose(size);

    final BoxConstraints fullWidthConstraints =
        looseConstraints.tighten(width: size.width);
    final double bottom = size.height;
    double contentTop = 0.0;
    double footerHeight = 0.0;
    double footerTop;

    if (hasChild(_FooterSlot.footer)) {
      final double bottomHeight =
          layoutChild(_FooterSlot.footer, fullWidthConstraints).height;
      footerHeight += bottomHeight;
      footerTop = math.max(0.0, bottom - footerHeight);
      positionChild(_FooterSlot.footer, Offset(0.0, footerTop));
    }

    final double contentBottom =
        math.max(0.0, bottom - math.max(minInsets.bottom, footerHeight));

    if (hasChild(_FooterSlot.body)) {
      double bodyMaxHeight = math.max(0.0, contentBottom - contentTop);

      final BoxConstraints bodyConstraints = BodyBoxConstraints(
        maxWidth: fullWidthConstraints.maxWidth,
        maxHeight: bodyMaxHeight,
        footerHeight: footerHeight,
      );
      layoutChild(_FooterSlot.body, bodyConstraints);
      positionChild(_FooterSlot.body, Offset(0.0, contentTop));
    }
  }

  @override
  bool shouldRelayout(_FooterLayout oldDelegate) {
    return oldDelegate.minInsets != minInsets;
  }
}

class FooterLayout extends StatefulWidget {
  final Widget body;
  final Widget? footer;

  const FooterLayout({super.key, required this.body, this.footer});

  @override
  State<StatefulWidget> createState() => _FooterLayoutState();
}

class _FooterLayoutState extends State<FooterLayout> {
  @override
  Widget build(BuildContext context) {
    List<LayoutId> children = [];
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    EdgeInsets minInset = mediaQuery.padding.copyWith(bottom: 0.0);

    _addIfNonNull(
      children,
      widget.body,
      _FooterSlot.body,
      removeLeftPadding: false,
      removeTopPadding: false,
      removeRightPadding: false,
      removeBottomPadding: true,
    );

    if (widget.footer != null) {
      _addIfNonNull(
        children,
        widget.footer!,
        _FooterSlot.footer,
        removeLeftPadding: false,
        removeTopPadding: true,
        removeRightPadding: false,
        removeBottomPadding: false,
      );
    }

    return CustomMultiChildLayout(
      delegate: _FooterLayout(minInsets: minInset),
      children: children,
    );
  }

  void _addIfNonNull(
    List<LayoutId> children,
    Widget child,
    Object childId, {
    required bool removeLeftPadding,
    required bool removeTopPadding,
    required bool removeRightPadding,
    required bool removeBottomPadding,
    bool removeBottomInset = false,
    bool maintainBottomViewPadding = false,
  }) {
    MediaQueryData data = MediaQuery.of(context).removePadding(
      removeLeft: removeLeftPadding,
      removeTop: removeTopPadding,
      removeRight: removeRightPadding,
      removeBottom: removeBottomPadding,
    );
    if (removeBottomInset) data = data.removeViewInsets(removeBottom: true);

    if (maintainBottomViewPadding && data.viewInsets.bottom != 0.0) {
      data = data.copyWith(
          padding: data.padding.copyWith(bottom: data.viewPadding.bottom));
    }

    children.add(
      LayoutId(
        id: childId,
        child: MediaQuery(data: data, child: child),
      ),
    );
  }
}

class BodyBoxConstraints extends BoxConstraints {
  const BodyBoxConstraints({
    double minWidth = 0.0,
    double maxWidth = double.infinity,
    double minHeight = 0.0,
    double maxHeight = double.infinity,
    required this.footerHeight,
  })  : assert(footerHeight >= 0),
        super(
            minWidth: minWidth,
            maxWidth: maxWidth,
            minHeight: minHeight,
            maxHeight: maxHeight);

  final double footerHeight;

  // RenderObject.layout() will only short-circuit its call to its performLayout
  // method if the new layout constraints are not == to the current constraints.
  // If the height of the bottom widgets has changed, even though the constraints'
  // min and max values have not, we still want performLayout to happen.
  @override
  bool operator ==(Object other) {
    if (super != other) return false;
    return other is BodyBoxConstraints && other.footerHeight == footerHeight;
  }

  @override
  int get hashCode {
    return Object.hash(super.hashCode, footerHeight);
  }
}
