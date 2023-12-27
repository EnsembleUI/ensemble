import 'dart:math';

import 'package:ensemble/action/haptic_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/event.dart';
import 'package:ensemble/framework/extensions.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/widget/colored_box_placeholder.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/framework/widget/image.dart' as framework;
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble/widget/helpers/widgets.dart';
import 'package:ensemble/widget/image.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class Avatar extends EnsembleWidget<AvatarController> {
  static const type = 'Avatar';

  const Avatar._(super.controller, {super.key});

  factory Avatar.build(dynamic controller) => Avatar._(
      controller is AvatarController ? controller : AvatarController());

  @override
  State<StatefulWidget> createState() => AvatarState();
}

class AvatarController extends EnsembleBoxController {
  AvatarController() {
    clipContent = true;
  }

  String? name;
  TextStyle? nameTextStyle;

  String? source;
  BoxFit? fit;
  Color? placeholderColor;

  GroupTemplate? groupTemplate;

  AvatarVariant? variant;
  EnsembleAction? onTap;
  String? onTapHaptic;

  @override
  List<String> passthroughSetters() => ['group-template'];

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() => Map<String, Function>.from(super.setters())
    ..addAll({
      'name': (value) => name = Utils.optionalString(value),
      'nameTextStyle': (value) => nameTextStyle = Utils.getTextStyle(value),
      'source': (value) => source = Utils.optionalString(value),
      'fit': (value) => fit = Utils.getBoxFit(value),
      'placeholderColor': (value) => placeholderColor = Utils.getColor(value),
      'variant': (value) => variant = AvatarVariant.values.from(value),
      'onTap': (func) => onTap = EnsembleAction.fromYaml(func, initiator: this),
      'onTapHaptic': (value) => onTapHaptic = Utils.optionalString(value),
      'group-template': (value) => setGroupAvatar(value)
    });

  void setGroupAvatar(dynamic groupData) {
    if (groupData is! Map && groupData is! YamlMap) return;

    dynamic data = groupData['data'];
    String? name = groupData['name'];

    if (data == null || name == null) return;

    groupTemplate = GroupTemplate(
      data: data,
      name: name,
      max: Utils.optionalInt(groupData['max']),
      offset: Utils.getDouble(groupData['offset'], fallback: 30),
      surplusBackgroundColor:
          Utils.getColor(groupData['surplusBackgroundColor']),
      surplusTextStyle: Utils.getTextStyle(groupData['surplusTextStyle']),
      onSurplusTap:
          EnsembleAction.fromYaml(groupData['onSurplusTap'], initiator: this),
      avatarData: AvatarData.fromYaml(
        YamlMap.wrap(groupData?['template'] ?? {}),
      ),
    );
  }
}

class AvatarState extends EnsembleWidgetState<Avatar>
    with TemplatedWidgetState {
  static const defaultSize = 40.0;
  List<AvatarData> groupAvatar = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _registerGroupAvatarListener(context);
  }

  void _registerGroupAvatarListener(BuildContext context) {
    if (widget.controller.groupTemplate != null) {
      registerItemTemplate(
        context,
        widget.controller.groupTemplate!,
        evaluateInitialValue: true,
        onDataChanged: (dataList) {
          final avatars = _buildAvatarPayload(dataList);
          setState(() {
            groupAvatar = avatars;
          });
        },
      );
    }
  }

  List<AvatarData> _buildAvatarPayload(List dataList) {
    List<AvatarData> avatarData = [];

    GroupTemplate? itemTemplate = widget.controller.groupTemplate;
    ScopeManager? myScope = getScopeManager();
    if (myScope != null && itemTemplate != null) {
      for (dynamic dataItem in dataList) {
        ScopeManager dataScope = myScope.createChildScope();
        dataScope.dataContext.addDataContextById(itemTemplate.name, dataItem);

        avatarData.add(
          AvatarData(
            source: Utils.optionalString(
                dataScope.dataContext.eval(itemTemplate.avatarData.source)),
            boxFit: Utils.getBoxFit(
                dataScope.dataContext.eval(itemTemplate.avatarData.boxFit)),
            name: Utils.optionalString(
                dataScope.dataContext.eval(itemTemplate.avatarData.name)),
            nameTextStyle: Utils.getTextStyle(dataScope.dataContext
                .eval(itemTemplate.avatarData.nameTextStyle)),
            onTap: EnsembleAction.fromYaml(
                dataScope.dataContext.eval(itemTemplate.avatarData.onTap)),
            onTapHaptic: Utils.optionalString(dataScope.dataContext
                .eval(itemTemplate.avatarData.onTapHaptic)),
            placeholderColor: Utils.getColor(dataScope.dataContext
                .eval(itemTemplate.avatarData.placeholderColor)),
            variant: itemTemplate.avatarData.variant,
          ),
        );
      }
    }
    return avatarData;
  }

  @override
  Widget buildWidget(BuildContext context) {
    return widget.controller.groupTemplate == null
        ? _buildAvatar(AvatarData(
            boxFit: widget.controller.fit,
            name: widget.controller.name,
            nameTextStyle: widget.controller.nameTextStyle,
            onTap: widget.controller.onTap,
            onTapHaptic: widget.controller.onTapHaptic,
            placeholderColor: widget.controller.placeholderColor,
            source: widget.controller.source,
            variant: widget.controller.variant,
          ))
        : _buildGroupAvatar();
  }

  Widget _buildGroupAvatar() {
    final groupTemplate = widget.controller.groupTemplate;
    int? maxAvatars = groupTemplate?.max;
    double leftOffset = groupTemplate?.offset ?? 30.0;

    int surplusCount =
        maxAvatars == null ? 0 : max(0, groupAvatar.length - maxAvatars);

    Widget surplusBuilder() {
      return Padding(
        padding: EdgeInsets.only(
            left: maxAvatars == null
                ? min(
                    MediaQuery.of(context).size.width,
                    leftOffset * groupAvatar.length,
                  )
                : leftOffset * maxAvatars),
        child: CircleAvatar(
          backgroundColor: groupTemplate?.surplusBackgroundColor,
          child: Text(
            '+$surplusCount',
            style: groupTemplate?.surplusTextStyle,
          ),
        ),
      );
    }

    Widget surplus = surplusBuilder();
    if (groupTemplate?.onSurplusTap != null) {
      surplus = InkWell(
        onTap: () {
          ScreenController().executeAction(
            context,
            groupTemplate!.onSurplusTap!,
            event: EnsembleEvent(widget.controller),
          );
        },
        child: surplus,
      );
    }

    return Stack(
      children: [
        for (var i = 0;
            i < min(groupAvatar.length, maxAvatars ?? groupAvatar.length);
            i++)
          Transform.translate(
            offset: Offset(i * leftOffset, 0),
            child: _buildAvatar(groupAvatar[i]),
          ),
        if (surplusCount > 0) surplus
      ],
    );
  }

  Widget _buildAvatar(AvatarData avatarData) {
    String? source = avatarData.source?.trim();
    Widget content = EnsembleBoxWrapper(
      widget: source != null && source.isNotEmpty
          ? _buildImage(source, avatarData)
          : _buildFallback(avatarData),
      boxController: widget.controller,
      ignoresMargin: true,
      fallbackWidth: width,
      fallbackHeight: height,
      fallbackBorderRadius: _getVariantDefaultBorderRadius(avatarData.variant),
    );

    if (avatarData.onTap != null) {
      content = GestureDetector(
        child: content,
        onTap: () {
          if (avatarData.onTapHaptic != null) {
            ScreenController().executeAction(
              context,
              HapticAction(
                type: avatarData.onTapHaptic!,
                onComplete: null,
              ),
            );
          }

          ScreenController().executeAction(context, avatarData.onTap!,
              event: EnsembleEvent(widget.controller));
        },
      );
    }
    if (widget.controller.margin != null) {
      content = Padding(padding: widget.controller.margin!, child: content);
    }
    return content;
  }

  EBorderRadius? _getVariantDefaultBorderRadius(AvatarVariant? variant) {
    switch (variant) {
      case AvatarVariant.square:
        return null;
      case AvatarVariant.rounded:
        return EBorderRadius.all(10);
      case AvatarVariant.circle:
      default:
        return EBorderRadius.all(9999);
    }
  }

  Widget _buildImage(String source, AvatarData avatarData) => framework.Image(
      source: source,
      fit: widget.controller.fit,
      networkCacheManager: EnsembleImageCacheManager.instance,
      placeholderBuilder: (_, __) =>
          ColoredBoxPlaceholder(color: widget.controller.placeholderColor),
      errorBuilder: (_) => _buildFallback(avatarData));

  /// build the initial or an empty box
  Widget _buildFallback(AvatarData avatarData) {
    String? initial;
    String? name = avatarData.name?.trim();
    if (name != null && name.isNotEmpty) {
      List<String> tokens = name.split(RegExp(r'\s+'));
      initial = tokens[0][0].toUpperCase();
      if (tokens.length > 1) {
        initial += tokens[tokens.length - 1][0].toUpperCase();
      }
    }

    var textStyle = avatarData.nameTextStyle ??
        TextStyle(fontSize: min(width, height) * .5);
    return initial != null
        ? Align(child: Text(initial, style: textStyle))
        : const SizedBox.shrink();
  }

  double get width =>
      (widget.controller.width ?? widget.controller.height)?.toDouble() ??
      defaultSize;

  double get height =>
      (widget.controller.height ?? widget.controller.width)?.toDouble() ??
      defaultSize;
}

enum AvatarVariant { circle, square, rounded }

class GroupTemplate extends ItemTemplate {
  GroupTemplate({
    required dynamic data,
    required String name,
    dynamic template,
    this.max,
    required this.avatarData,
    this.offset = 30,
    this.surplusBackgroundColor,
    this.surplusTextStyle,
    this.onSurplusTap,
  }) : super(data, name, template);

  final int? max;
  final double offset;
  final Color? surplusBackgroundColor;
  final TextStyle? surplusTextStyle;
  final EnsembleAction? onSurplusTap;

  final AvatarData avatarData;
}

class AvatarData {
  final String? name;
  final TextStyle? nameTextStyle;
  final String? source;
  final BoxFit? boxFit;
  final Color? placeholderColor;
  final AvatarVariant? variant;
  final EnsembleAction? onTap;
  final String? onTapHaptic;

  AvatarData(
      {this.name,
      this.nameTextStyle,
      this.source,
      this.boxFit,
      this.placeholderColor,
      this.variant,
      this.onTap,
      this.onTapHaptic});

  factory AvatarData.fromYaml(YamlMap yamlMap) => AvatarData(
        name: Utils.optionalString(yamlMap['name']),
        nameTextStyle: Utils.getTextStyle(yamlMap['nameTextStyle']),
        source: Utils.optionalString(yamlMap['source']),
        boxFit: Utils.getBoxFit(yamlMap['fit']),
        placeholderColor: Utils.getColor(yamlMap['placeHolderColor']),
        variant: AvatarVariant.values.from(yamlMap['variant']),
        onTap: EnsembleAction.fromYaml(yamlMap['onTap']),
        onTapHaptic: Utils.optionalString(yamlMap['onTapHaptic']),
      );
}
