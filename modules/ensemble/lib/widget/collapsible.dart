import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';
import 'package:accordion/accordion.dart';
import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:yaml/yaml.dart';
import 'package:ensemble/framework/widget/icon.dart' as ensembleIcon;

class HeaderStyle {
  Color? backgroundColor;
  Color? backgroundColorOpened;
  Color? borderColor;
  Color? borderColorOpened;
  double? borderWidth;
  double? borderRadius;
  EdgeInsets? padding;

  HeaderStyle({
    this.backgroundColor,
    this.backgroundColorOpened,
    this.borderColor,
    this.borderColorOpened,
    this.borderWidth,
    this.borderRadius,
    this.padding,
  });
}

class ContentStyle {
  Color? backgroundColor;
  Color? borderColor;
  double? borderWidth;
  double? borderRadius;
  double? horizontalPadding;
  double? verticalPadding;

  ContentStyle({
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
    this.borderRadius,
    this.horizontalPadding,
    this.verticalPadding,
  });
}

class Collapsible extends StatefulWidget
    with
        Invokable,
        HasController<CollapsibleController, CollapsibleState> {
  static const type = 'Collapsible';

  Collapsible({Key? key}) : super(key: key);

  final CollapsibleController _controller = CollapsibleController();

  @override
  CollapsibleController get controller => _controller;

  @override
  State<StatefulWidget> createState() => CollapsibleState();

  @override
  Map<String, Function> getters() {
    return {
      'openSections': () => _controller.openSections,
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'items': (value) => _controller.items = List<YamlMap>.from(value),
      'isAccordion': (value) => _controller.isAccordion = Utils.getBool(value, fallback: true),
      'initialOpeningSequenceDelay': (value) =>
          _controller.initialOpeningSequenceDelay = Utils.optionalInt(value),
      'headerStyle': (value) => _controller.headerStyle = HeaderStyle(
        backgroundColor: Utils.getColor(value['backgroundColor']),
        backgroundColorOpened: Utils.getColor(value['backgroundColorOpened']),
        borderColor: Utils.getColor(value['borderColor']),
        borderColorOpened: Utils.getColor(value['borderColorOpened']),
        borderWidth: Utils.optionalDouble(value['borderWidth']),
        borderRadius: Utils.optionalDouble(value['borderRadius']),
        padding: Utils.optionalInsets(value['padding']),
      ),
      'contentStyle': (value) => _controller.contentStyle = ContentStyle(
        backgroundColor: Utils.getColor(value['backgroundColor']),
        borderColor: Utils.getColor(value['borderColor']),
        borderWidth: Utils.optionalDouble(value['borderWidth']),
        borderRadius: Utils.optionalDouble(value['borderRadius']),
        horizontalPadding: Utils.optionalDouble(value['horizontalPadding']),
        verticalPadding: Utils.optionalDouble(value['verticalPadding']),
      ),
      'leftIcon': (value) => _controller.leftIcon = value,
      'rightIcon': (value) => _controller.rightIcon = value,
      'flipLeftIconIfOpen': (value) =>
          _controller.flipLeftIconIfOpen = Utils.optionalBool(value),
      'flipRightIconIfOpen': (value) =>
          _controller.flipRightIconIfOpen = Utils.optionalBool(value),
      'paddingListTop': (value) =>
          _controller.paddingListTop = Utils.getDouble(value, fallback: 0.0),
      'paddingListBottom': (value) =>
          _controller.paddingListBottom = Utils.getDouble(value, fallback: 0.0),
      'paddingListHorizontal': (value) => _controller.paddingListHorizontal =
          Utils.getDouble(value, fallback: 0.0),
      'paddingBetweenOpenSections': (value) =>
          _controller.paddingBetweenOpenSections = Utils.optionalDouble(value),
      'paddingBetweenClosedSections': (value) => _controller
          .paddingBetweenClosedSections = Utils.optionalDouble(value),
      'disableScrolling': (value) =>
          _controller.disableScrolling = Utils.getBool(value, fallback: false),
      'openAndCloseAnimation': (value) =>
          _controller.openAndCloseAnimation = Utils.optionalBool(value),
      'scaleWhenAnimating': (value) =>
          _controller.scaleWhenAnimating = Utils.optionalBool(value),
      'accordionId': (value) =>
          _controller.accordionId = Utils.optionalString(value),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'openSection': (int index) => _controller.openSection(index),
      'closeSection': (int index) => _controller.closeSection(index),
    };
  }
}

class CollapsibleController extends BoxController {
  List<YamlMap> items = [];
  bool isAccordion = true;
  int? initialOpeningSequenceDelay;
  HeaderStyle headerStyle = HeaderStyle();
  ContentStyle contentStyle = ContentStyle();
  dynamic leftIcon;
  dynamic rightIcon;
  bool? flipLeftIconIfOpen;
  bool? flipRightIconIfOpen;
  double paddingListTop = 0.0;
  double paddingListBottom = 0.0;
  double paddingListHorizontal = 0.0;
  double? paddingBetweenOpenSections;
  double? paddingBetweenClosedSections;
  bool disableScrolling = false;
  bool? openAndCloseAnimation;
  bool? scaleWhenAnimating;
  String? accordionId;

  final ValueNotifier<List<int>> _openSections = ValueNotifier<List<int>>([]);
  List<int> get openSections => _openSections.value;

  void openSection(int index) {
    if (isAccordion) {
      _openSections.value = [index];
    } else {
      final newOpenSections = List<int>.from(_openSections.value);
      if (newOpenSections.contains(index)) {
        newOpenSections.remove(index);
      } else {
        newOpenSections.add(index);
      }
      _openSections.value = newOpenSections;
    }
  }

  void closeSection(int index) {
    final newOpenSections = List<int>.from(_openSections.value);
    newOpenSections.remove(index);
    _openSections.value = newOpenSections;
  }

  @override
  void dispose() {
  }
}

class CollapsibleState extends EWidgetState<Collapsible> {

  @override
  void initState() {
    super.initState();
    final initialOpenSections = <int>[];
    for (int i = 0; i < widget.controller.items.length; i++) {
      if (widget.controller.items[i]['isOpen'] == true) {
        initialOpenSections.add(i);
      }
    }
    widget.controller._openSections.value = initialOpenSections;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return Accordion(
      maxOpenSections: widget.controller.isAccordion ? 1 : widget.controller.items.length,
      initialOpeningSequenceDelay:
          widget.controller.initialOpeningSequenceDelay ?? 0,
      headerBackgroundColor:
          widget.controller.headerStyle.backgroundColor,
      headerBackgroundColorOpened:
          widget.controller.headerStyle.backgroundColorOpened,
      headerBorderColor: widget.controller.headerStyle.borderColor,
      headerBorderColorOpened:
          widget.controller.headerStyle.borderColorOpened,
      headerBorderWidth: widget.controller.headerStyle.borderWidth ?? 1.0,
      headerBorderRadius: widget.controller.headerStyle.borderRadius ?? 0.0,
      flipLeftIconIfOpen: widget.controller.flipLeftIconIfOpen ?? false,
      flipRightIconIfOpen: widget.controller.flipRightIconIfOpen ?? true,
      contentBackgroundColor:
          widget.controller.contentStyle.backgroundColor,
      contentBorderColor: widget.controller.contentStyle.borderColor,
      contentBorderWidth: widget.controller.contentStyle.borderWidth ?? 1.0,
      contentBorderRadius: widget.controller.contentStyle.borderRadius ?? 0.0,
      contentHorizontalPadding:
          widget.controller.contentStyle.horizontalPadding ?? 0.0,
      contentVerticalPadding: widget.controller.contentStyle.verticalPadding ?? 0.0,
      paddingListTop: widget.controller.paddingListTop,
      paddingListBottom: widget.controller.paddingListBottom,
      paddingListHorizontal: widget.controller.paddingListHorizontal,
      headerPadding: widget.controller.headerStyle.padding ?? EdgeInsets.zero,
      paddingBetweenOpenSections:
          widget.controller.paddingBetweenOpenSections ?? 0.0,
      paddingBetweenClosedSections:
          widget.controller.paddingBetweenClosedSections ?? 0.0,
      disableScrolling: widget.controller.disableScrolling,
      openAndCloseAnimation: widget.controller.openAndCloseAnimation ?? true,
      scaleWhenAnimating: widget.controller.scaleWhenAnimating ?? true,
      leftIcon: _buildIcon(widget.controller.leftIcon),
      rightIcon: _buildIcon(widget.controller.rightIcon),
      accordionId: widget.controller.accordionId ?? 'default_accordion',
      children: List.generate(widget.controller.items.length, (index) {
        final item = widget.controller.items[index];
        final isOpen = widget.controller.openSections.contains(index);
        return AccordionSection(
          isOpen: isOpen,
          headerBackgroundColor:
              Utils.getColor(item['headerStyle']?['backgroundColor']) ??
                  widget.controller.headerStyle.backgroundColor,
          headerBackgroundColorOpened:
              Utils.getColor(item['headerStyle']?['backgroundColorOpened']) ??
                  widget.controller.headerStyle.backgroundColorOpened,
          headerBorderColor:Utils.getColor(item['headerStyle']?['borderColor']) ??
              widget.controller.headerStyle.borderColor,
          headerBorderColorOpened:
              Utils.getColor(item['headerStyle']?['borderColorOpened']) ??
                  widget.controller.headerStyle.borderColorOpened,
          headerBorderWidth: Utils.optionalDouble(item['headerStyle']?['borderWidth']) ??
              widget.controller.headerStyle.borderWidth,
          headerBorderRadius:
              Utils.optionalDouble(item['headerStyle']?['borderRadius']) ??
                  widget.controller.headerStyle.borderRadius,
          headerPadding: Utils.optionalInsets(item['headerStyle']?['padding']) ??
              widget.controller.headerStyle.padding,
          contentBackgroundColor:
              Utils.getColor(item['contentStyle']?['backgroundColor']) ??
                  widget.controller.contentStyle.backgroundColor,
          contentBorderColor: Utils.getColor(item['contentStyle']?['borderColor']) ??
              widget.controller.contentStyle.borderColor,
          contentBorderWidth:
              Utils.optionalDouble(item['contentStyle']?['borderWidth']) ??
                  widget.controller.contentStyle.borderWidth,
          contentBorderRadius:
              Utils.optionalDouble(item['contentStyle']?['borderRadius'])  ??
                  widget.controller.contentStyle.borderRadius,
          contentHorizontalPadding:
              Utils.optionalDouble(item['contentStyle']?['horizontalPadding']) ??
                  widget.controller.contentStyle.horizontalPadding,
          contentVerticalPadding:
              Utils.optionalDouble(item['contentStyle']?['verticalPadding']) ??
                  widget.controller.contentStyle.verticalPadding,
          leftIcon: _buildIcon(item['leftIcon']) ??
              _buildIcon(widget.controller.leftIcon),
          rightIcon: _buildIcon(item['rightIcon']) ??
              _buildIcon(widget.controller.rightIcon),
          paddingBetweenOpenSections:
              Utils.optionalDouble(item['paddingBetweenOpenSections']) ?? widget.controller.paddingBetweenOpenSections,
          paddingBetweenClosedSections:
              Utils.optionalDouble(item['paddingBetweenClosedSections']) ?? widget.controller.paddingBetweenClosedSections,
          header: _buildChildWidget(context, item['header']) ??
              Text('Section $index'),
          content: _buildChildWidget(context, item['content']) ??
              Text('Content for section $index'),
          onOpenSection: () {
            setState(() {
              widget.controller.openSection(index);
            });
            if (item['onOpenSection'] != null) {
              final onOpenAction = EnsembleAction.from(item['onOpenSection'], initiator: widget);
              ScreenController().executeAction(
                context,
                onOpenAction!,
                event: EnsembleEvent(widget, data: {'index': index}),
              );
            }
          },
          onCloseSection: () {
            setState(() {
              widget.controller.closeSection(index);
            });
            if (item['onCloseSection'] != null) {
              final onCloseAction = EnsembleAction.from(item['onCloseSection'], initiator: widget);
              ScreenController().executeAction(
                context,
                onCloseAction!,
                event: EnsembleEvent(widget, data: {'index': index}),
              );
            }
          },
        );
      }),
    );
  }

  Widget? _buildIcon(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Map && value['Icon'] != null) {
      final iconModel = Utils.getIcon(value['Icon']);
      if (iconModel != null) {
        return ensembleIcon.Icon.fromModel(iconModel);
      }
    }
    return null;
  }

  Widget? _buildChildWidget(BuildContext context, dynamic widgetDefinition) {
    if (widgetDefinition == null) {
      return null;
    }
    ScopeManager? scopeManager = DataScopeWidget.getScope(context);
    if (scopeManager != null) {
      return scopeManager.buildWidgetFromDefinition(widgetDefinition);
    } else {
      throw LanguageError('Failed to build widget');
    }
  }
}