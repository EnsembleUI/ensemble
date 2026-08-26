// ignore_for_file: avoid_print

import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/ensemble_bracket.dart';
import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/framework/tv/tv_focus_order.dart';
import 'package:ensemble/framework/tv/tv_focus_provider.dart';
import 'package:ensemble/framework/tv/tv_focus_widget.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/model/item_template.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Implementation of the tournament bracket widget for Ensemble.
class EnsembleBracketImpl extends EnsembleWidget<BracketController>
    implements EnsembleBracket {
  const EnsembleBracketImpl._(super.controller);

  /// Factory constructor to build the [EnsembleBracketImpl] widget.
  factory EnsembleBracketImpl.build([dynamic controller]) =>
      EnsembleBracketImpl._(
          controller is BracketController ? controller : BracketController());

  @override
  State<StatefulWidget> createState() => BracketState();
}

/// Template representing a round in the tournament bracket.
class RoundTemplate extends ItemTemplate {
  /// The title of the round.
  final String? title;

  /// The matches within the round.
  final MatchTemplate matches;

  /// Creates a [RoundTemplate].
  RoundTemplate({
    required String? data,
    required String name,
    dynamic template,
    required this.title,
    required this.matches,
  }) : super(data, name, template);
}

/// Template representing a match within a round.
class MatchTemplate extends ItemTemplate {
  /// The height of the match container.
  final double height;

  /// Creates a [MatchTemplate].
  MatchTemplate(super.data, super.name, super.template, this.height);
}

/// Data object containing resolved information for a round.
class RoundData {
  /// The title of the round.
  final String title;

  /// The match template configuration.
  final MatchTemplate matches;

  /// The local scope manager for evaluated variables in the round.
  final ScopeManager localScope;

  /// Creates a [RoundData] object.
  RoundData({
    required this.title,
    required this.matches,
    required this.localScope,
  });
}

/// Controller managing styling and properties of the [EnsembleBracketImpl] widget.
class BracketController extends EnsembleBoxController {
  /// Padding for the bracket tabs.
  EdgeInsets? tabPadding;

  /// Gap between tabs.
  double tabGap = 12;

  /// Leading inset inside every round page.
  double? leftEdgePadding;

  /// Trailing inset applied only to the final round page.
  double? rightEdgePadding;

  /// Symmetric inset for the round-title strip.
  double headerPadding = 0;

  /// Creates a [BracketController].
  BracketController();

  RoundTemplate? roundTemplate;
  Color? lineColor;
  double? lineWidth;

  Color? tabBackgroundColor;
  Color? tabSelectedBackgroundColor;
  TextStyle? tabTextStyle;
  TextStyle? tabSelectedStyle;
  EBorderRadius? tabBorderRadius;
  Color? tabBorderColor;
  double? tabBorderWidth;
  Color? tabSelectedBorderColor;
  double? tabSelectedBorderWidth;

  // Tab focus styling (TV D-pad)
  Color? tabFocusColor;
  double? tabFocusBorderWidth;
  EBorderRadius? tabFocusBorderRadius;
  int? tabFocusAnimationDurationMs;
  Color? tabFocusBackgroundColor;
  TextStyle? tabFocusTextStyle;

  // TV navigation row offset - tabs will be at this row, matches at row+1, row+2, etc.
  int tvRowOffset = 0;

  // Layout scale (0.1 - 1.0). Baseline 0.75 = current defaults.
  // Controls viewportFraction, matchCardWidthFraction, and connectorLength proportionally.
  double? _scale;

  // Computed layout values based on scale.
  // Baseline: scale=0.75 → viewportFraction=0.75, cardWidth=0.6, connector=25
  double get viewportFraction => _scale ?? 0.75;
  double get matchCardWidthFraction =>
      _scale != null ? 0.6 * (_scale! / 0.75) : 0.6;
  double get connectorLength => _scale != null ? 25.0 * (_scale! / 0.75) : 25.0;

  @override
  List<String> passthroughSetters() => ['items'];

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
      'scale': (value) {
        final parsed = Utils.optionalDouble(value);
        if (parsed != null) {
          _scale = parsed.clamp(0.1, 1.0);
        }
      },
      'tvOptions': (data) {
        if (data is Map) {
          tvRowOffset = Utils.getInt(data['row'], fallback: 0);
        }
      },
      'leftEdgePadding': (value) {
        leftEdgePadding = (Utils.optionalDouble(value) ?? 0)
            .clamp(0, double.infinity)
            .toDouble();
      },
      'rightEdgePadding': (value) {
        rightEdgePadding = (Utils.optionalDouble(value) ?? 0)
            .clamp(0, double.infinity)
            .toDouble();
      },
      'headerPadding': (value) {
        headerPadding = (Utils.optionalDouble(value) ?? 0)
            .clamp(0, double.infinity)
            .toDouble();
      },
      'lineStyles': (data) {
        lineColor = Utils.getColor(data['color']);
        lineWidth = Utils.optionalDouble(data['width']);
      },
      'tabStyles': (data) {
        tabBackgroundColor = Utils.getColor(data['backgroundColor']);
        tabSelectedBackgroundColor =
            Utils.getColor(data['selectedBackgroundColor']);
        tabTextStyle = Utils.getTextStyle(data['textStyle']);
        tabSelectedStyle = Utils.getTextStyle(data['selectedTextStyle']);
        tabBorderRadius = Utils.getBorderRadius(data['borderRadius']);
        tabBorderColor = Utils.getColor(data['borderColor']);
        tabBorderWidth = Utils.optionalDouble(data['borderWidth']);
        tabSelectedBorderColor = Utils.getColor(data['selectedBorderColor']);
        tabSelectedBorderWidth =
            Utils.optionalDouble(data['selectedBorderWidth']);
        tabPadding = Utils.optionalInsets(data['padding']);
        tabGap = Utils.getDouble(data['gap'], fallback: 12.0);
        tabFocusColor = Utils.getColor(data['focusBorderColor']);
        tabFocusBorderWidth = Utils.optionalDouble(data['focusBorderWidth']);
        tabFocusBorderRadius = Utils.getBorderRadius(data['focusBorderRadius']);
        tabFocusAnimationDurationMs =
            Utils.optionalInt(data['focusAnimationDurationMs']);
        tabFocusBackgroundColor = Utils.getColor(data['focusBackgroundColor']);
        tabFocusTextStyle = Utils.getTextStyle(data['focusTextStyle']);
      },
      'items': (data) {
        if (!_isValidData(data)) return;

        roundTemplate = RoundTemplate(
          data: Utils.optionalString(data['data']),
          name: Utils.optionalString(data['name']) ?? 'round',
          title: Utils.optionalString(data['title']),
          matches: MatchTemplate(
              Utils.optionalString(data['item-template']['data']),
              Utils.optionalString(data['item-template']['name']) ?? 'match',
              data['item-template']['template'],
              Utils.getDouble(
                data['item-template']['height'],
                fallback: 100,
              )),
        );
      }
    });

  bool _isValidData(dynamic data) {
    if (data is! Map) {
      print('Bracket: Invalid items');
      return false;
    }
    if (data['data'] == null || data['name'] == null) {
      print('Bracket: data and name are required');
      return false;
    }
    if (data['item-template'] == null) {
      print('Bracket: item-template is required');
      return false;
    }
    return true;
  }
}

class BracketState extends EnsembleWidgetState<EnsembleBracketImpl>
    with TemplatedWidgetState {
  List<RoundData> roundData = [];

  @override
  void didChangeDependencies() {
    _registerRowSpanListener(context);
    super.didChangeDependencies();
  }

  List<RoundData> _buildRoundConfig(BuildContext context, List dataList) {
    List<RoundData> roundDataConfig = [];

    RoundTemplate? itemTemplate = widget.controller.roundTemplate;
    ScopeManager? myScope = DataScopeWidget.getScope(context);
    if (myScope != null && itemTemplate != null) {
      for (int i = 0; i < dataList.length; i++) {
        dynamic dataItem = dataList[i];
        ScopeManager dataScope = myScope.createChildScope();
        dataScope.dataContext.addDataContextById(itemTemplate.name, dataItem);
        // Add roundIndex to scope for TV navigation (tvOptions.order: ${roundIndex})
        dataScope.dataContext.addDataContextById('roundIndex', i);

        roundDataConfig.add(
          RoundData(
            title: Utils.getString(
              dataScope.dataContext.eval(itemTemplate.title),
              fallback: '--',
            ),
            matches: itemTemplate.matches,
            localScope: dataScope,
          ),
        );
      }
    }
    return roundDataConfig;
  }

  void _registerRowSpanListener(BuildContext context) {
    if (widget.controller.roundTemplate != null) {
      registerItemTemplate(context, widget.controller.roundTemplate!,
          onDataChanged: (dataList) {
        if (dataList is List) {
          roundData = _buildRoundConfig(context, dataList);
          setState(() {});
        }
      });
    }
  }

  @override
  Widget buildWidget(BuildContext context) {
    return BracketsView(
      controller: widget.controller,
      data: roundData,
      tvRowOffset: widget.controller.tvRowOffset,
    );
  }
}

class BracketsView extends StatefulWidget {
  final List<RoundData> data;
  final BracketController controller;
  final int tvRowOffset;

  const BracketsView({
    super.key,
    required this.data,
    required this.controller,
    this.tvRowOffset = 0,
  });

  @override
  State<BracketsView> createState() => _BracketsViewState();
}

class _BracketsViewState extends State<BracketsView> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  // Target page controls column expansion.
  int _prevColumnIndex = 0;
  List<GlobalKey> _tabKeys = [];
  // Prevents child focus handling from scrolling horizontally.
  final _bracketTVFocusProvider = _BracketTVFocusProvider();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      viewportFraction: widget.controller.viewportFraction,
    );
    _pageController.addListener(_updatePageIndex);
  }

  @override
  void didUpdateWidget(covariant BracketsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTabKeys();
    // Recreate PageController if viewportFraction changed
    if (oldWidget.controller.viewportFraction !=
        widget.controller.viewportFraction) {
      final currentPage = _pageController.page?.round() ?? 0;
      _pageController.removeListener(_updatePageIndex);
      _pageController.dispose();
      _pageController = PageController(
        viewportFraction: widget.controller.viewportFraction,
        initialPage: currentPage,
      );
      _pageController.addListener(_updatePageIndex);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTabKeys();
  }

  // Regenerate tab keys when the round count changes.
  void _syncTabKeys() {
    if (_tabKeys.length != widget.data.length) {
      _tabKeys =
          List<GlobalKey>.generate(widget.data.length, (index) => GlobalKey());
    }
  }

  void _updatePageIndex() {
    int newPage = _pageController.page!.round();
    if (newPage != _currentPageIndex) {
      setState(() {
        _currentPageIndex = newPage;
        // On mobile, a horizontal swipe changes the page but not the reference
        // lane used for column spacing (_prevColumnIndex). Sync it here so tiles
        // realign after a swipe exactly as they do after a tab tap. TV drives
        // _prevColumnIndex via the keyboard-navigation callback instead.
        if (!Device().isTV) {
          _prevColumnIndex = newPage;
        }
      });
    }
    _scrollToSelectedTab(newPage);
  }

  void _scrollToSelectedTab(int index) {
    if (index < _tabKeys.length) {
      final context = _tabKeys[index].currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      }
    }
  }

  void _animateToPage(int index) {
    // Update _prevColumnIndex BEFORE animation to trigger column expansion
    setState(() {
      _prevColumnIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _pageController.removeListener(_updatePageIndex);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_tabKeys.isNotEmpty)
          SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: widget.controller.headerPadding,
            ),
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(widget.data.length, (index) {
                // On TV, tab selection follows _prevColumnIndex — the true
                // navigation target — because _pageController.page (which drives
                // _currentPageIndex) clamps on the last pages with padEnds:false,
                // so the final tab would never register as selected. Mobile keeps
                // _currentPageIndex since swipes update it directly.
                bool isSelected = index ==
                    (Device().isTV ? _prevColumnIndex : _currentPageIndex);
                String? title = widget.data.elementAt(index).title;

                // Wrap with TVFocusWidget for D-pad navigation on TV
                if (Device().isTV) {
                  return _buildTVTabButton(
                    context,
                    index: index,
                    title: title,
                    isSelected: isSelected,
                  );
                }

                final Color? mobileBorderColor = isSelected
                    ? (widget.controller.tabSelectedBorderColor ??
                        widget.controller.tabBorderColor)
                    : widget.controller.tabBorderColor;
                final double mobileBorderWidth = isSelected
                    ? (widget.controller.tabSelectedBorderWidth ??
                        widget.controller.tabBorderWidth ??
                        1.0)
                    : (widget.controller.tabBorderWidth ?? 1.0);

                return Container(
                  padding: EdgeInsets.only(left: widget.controller.tabGap),
                  child: ElevatedButton(
                    key: _tabKeys[index],
                    onPressed: () {
                      _animateToPage(index);
                      _scrollToSelectedTab(index);
                    },
                    style: ElevatedButton.styleFrom(
                      padding: widget.controller.tabPadding,
                      // Draw a resting border only when a border color is set, so
                      // apps that never set it keep their previous look.
                      shape: (widget.controller.tabBorderRadius != null ||
                              mobileBorderColor != null)
                          ? RoundedRectangleBorder(
                              borderRadius: widget.controller.tabBorderRadius
                                      ?.getValue() ??
                                  BorderRadius.zero,
                              side: mobileBorderColor != null
                                  ? BorderSide(
                                      color: mobileBorderColor,
                                      width: mobileBorderWidth,
                                    )
                                  : BorderSide.none,
                            )
                          : null,
                      backgroundColor: isSelected
                          ? widget.controller.tabSelectedBackgroundColor
                          : widget.controller.tabBackgroundColor,
                    ),
                    child: Text(
                      title,
                      style: isSelected
                          ? widget.controller.tabSelectedStyle
                          : widget.controller.tabTextStyle,
                    ),
                  ),
                );
              }),
            ),
          ),
        Expanded(
          // Wrap with TVFocusProviderScope to tell child widgets that
          // the bracket handles horizontal scrolling via PageView.
          // This prevents box_wrapper from calling Scrollable.ensureVisible()
          // which would cause horizontal jerk when navigating UP/DOWN.
          child: Device().isTV
              ? TVFocusProviderScope(
                  provider: _bracketTVFocusProvider,
                  child: BracketsPage(
                    controller: widget.controller,
                    pageController: _pageController,
                    data: widget.data,
                    tvRowOffset: widget.tvRowOffset,
                    prevColumnIndex: _prevColumnIndex,
                    onPrevColumnIndexChanged: (index) {
                      setState(() {
                        _prevColumnIndex = index;
                      });
                      _scrollToSelectedTab(index);
                    },
                  ),
                )
              : BracketsPage(
                  controller: widget.controller,
                  pageController: _pageController,
                  data: widget.data,
                  tvRowOffset: widget.tvRowOffset,
                  prevColumnIndex: _prevColumnIndex,
                  onPrevColumnIndexChanged: (index) {
                    setState(() {
                      _prevColumnIndex = index;
                    });
                  },
                ),
        ),
      ],
    );

    // NOTE: We no longer wrap with FocusTraversalGroup here because:
    // 1. The outer View already has a FocusTraversalGroup with TVFocusOrderTraversalPolicy
    // 2. Nested FocusTraversalGroups isolate focus, preventing navigation from header (BackArrow) to bracket
    // The outer View's FocusTraversalGroup handles all TV navigation using row/order from tvOptions.

    return content;
  }

  /// Build a TV-focusable tab button with focus styling
  Widget _buildTVTabButton(
    BuildContext context, {
    required int index,
    required String title,
    required bool isSelected,
  }) {
    return _TVTabButton(
      tabKey: _tabKeys[index],
      index: index,
      title: title,
      isSelected: isSelected,
      controller: widget.controller,
      tvRowOffset: widget.tvRowOffset,
      onPressed: () {
        _animateToPage(index);
        _scrollToSelectedTab(index);
      },
    );
  }
}

/// Stateful TV tab button that can track its own focus state
class _TVTabButton extends StatefulWidget {
  final GlobalKey tabKey;
  final int index;
  final String title;
  final bool isSelected;
  final BracketController controller;
  final int tvRowOffset;
  final VoidCallback onPressed;

  const _TVTabButton({
    required this.tabKey,
    required this.index,
    required this.title,
    required this.isSelected,
    required this.controller,
    required this.tvRowOffset,
    required this.onPressed,
  });

  @override
  State<_TVTabButton> createState() => _TVTabButtonState();
}

class _TVTabButtonState extends State<_TVTabButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeExtension = theme.extension<EnsembleThemeExtension>();
    final tvFocusTheme = themeExtension?.tvFocusTheme;
    final appPrimaryColor = theme.colorScheme.primary;
    final externalProvider = TVFocusProviderScope.maybeOf(context);

    // Priority: focusBorderColor > Theme > provider > borderColor > app primary
    final focusBorderColor = widget.controller.tabFocusColor ??
        tvFocusTheme?.focusBorderColor ??
        externalProvider?.focusBorderColor ??
        widget.controller.tabBorderColor ??
        appPrimaryColor;
    // Priority: focusBorderWidth > Theme > provider > borderWidth > default (2.0)
    final focusBorderWidth = widget.controller.tabFocusBorderWidth ??
        tvFocusTheme?.focusBorderWidth ??
        externalProvider?.focusBorderWidth ??
        widget.controller.tabBorderWidth ??
        2.0;
    // Priority: focusBorderRadius > Theme > provider > borderRadius > default (8.0)
    final borderRadius = widget.controller.tabFocusBorderRadius?.getValue() ??
        (tvFocusTheme?.focusBorderRadius != null
            ? BorderRadius.circular(tvFocusTheme!.focusBorderRadius!)
            : null) ??
        (externalProvider?.focusBorderRadius != null
            ? BorderRadius.circular(externalProvider!.focusBorderRadius!)
            : null) ??
        widget.controller.tabBorderRadius?.getValue() ??
        BorderRadius.circular(8);

    // Determine background color based on focus and selection state
    // Priority: focused > selected > default
    Color? backgroundColor;
    if (_isFocused && widget.controller.tabFocusBackgroundColor != null) {
      backgroundColor = widget.controller.tabFocusBackgroundColor;
    } else if (widget.isSelected) {
      backgroundColor = widget.controller.tabSelectedBackgroundColor;
    } else {
      backgroundColor = widget.controller.tabBackgroundColor;
    }

    // Determine text style based on focus and selection state
    // Priority: focused > selected > default
    TextStyle? textStyle;
    if (_isFocused && widget.controller.tabFocusTextStyle != null) {
      textStyle = widget.controller.tabFocusTextStyle;
    } else if (widget.isSelected) {
      textStyle = widget.controller.tabSelectedStyle;
    } else {
      textStyle = widget.controller.tabTextStyle;
    }

    // Resting-state border comes from the base tabStyles (borderColor/
    // borderWidth); focus overrides it. A border is always painted
    // (transparent + focus width when unset) to prevent size jerk on focus.
    // Selected tab may override the base border; priority focused > selected > normal.
    final restingBorderColor = widget.isSelected
        ? (widget.controller.tabSelectedBorderColor ??
            widget.controller.tabBorderColor ??
            Colors.transparent)
        : (widget.controller.tabBorderColor ?? Colors.transparent);
    final restingBorderWidth = widget.isSelected
        ? (widget.controller.tabSelectedBorderWidth ??
            widget.controller.tabBorderWidth ??
            focusBorderWidth)
        : (widget.controller.tabBorderWidth ?? focusBorderWidth);
    final borderColor = _isFocused ? focusBorderColor : restingBorderColor;
    final borderWidth = _isFocused ? focusBorderWidth : restingBorderWidth;

    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(
        widget.tvRowOffset.toDouble(), // Tab row from tvOptions
        order: widget.index.toDouble(),
        isRowEntryPoint: widget.isSelected, // Selected tab is entry point
      ),
      child: Container(
        padding: EdgeInsets.only(left: widget.controller.tabGap),
        child: Focus(
          onFocusChange: (hasFocus) {
            setState(() {
              _isFocused = hasFocus;
            });
          },
          child: ElevatedButton(
            key: widget.tabKey,
            onPressed: widget.onPressed,
            style: ElevatedButton.styleFrom(
              padding: widget.controller.tabPadding,
              backgroundColor: backgroundColor,
              // Disable Material focus/hover overlay to only show our custom border
              overlayColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: borderRadius,
                side: BorderSide(
                  color: borderColor,
                  width: borderWidth,
                ),
              ),
            ),
            child: Text(
              widget.title,
              style: textStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class BracketsPage extends StatefulWidget {
  final List<RoundData> data;
  final PageController pageController;
  final BracketController controller;
  final int tvRowOffset;
  final int prevColumnIndex;
  final ValueChanged<int>? onPrevColumnIndexChanged;

  const BracketsPage({
    super.key,
    required this.data,
    required this.pageController,
    required this.controller,
    this.tvRowOffset = 0,
    this.prevColumnIndex = 0,
    this.onPrevColumnIndexChanged,
  });

  @override
  State<BracketsPage> createState() => _BracketsPageState();
}

class _BracketsPageState extends State<BracketsPage>
    with SingleTickerProviderStateMixin {
  late List<ScrollController> _scrollControllers;

  // Own the FocusScope that wraps this bracket's pages so navigation can search
  // ONLY this bracket's focus subtree. A previous BracketView still mounted lower
  // in the navigator stack has its own duplicate column tiles in the global focus
  // tree; scanning globally can focus those off-screen ghosts (no visible ring).
  final FocusScopeNode _pageScopeNode =
      FocusScopeNode(debugLabel: 'BracketPageScope');
  final Map<_BracketMatchKey, FocusScopeNode> _matchFocusScopes = {};

  bool _scrollSyncScheduled = false;
  bool _isSynchronizingScrolls = false;
  int? _pendingScrollSyncColumn;
  bool _isHorizontalTransitioning = false;
  int _focusRequestGeneration = 0;
  double _logicalScrollOffset = 0;
  _BracketMatchKey? _focusedMatch;
  late int _activeColumnIndex;
  late final ValueNotifier<_BracketLayoutState> _layoutStateNotifier;
  late final AnimationController _layoutAnimationController;

  @override
  void initState() {
    super.initState();
    _activeColumnIndex = widget.prevColumnIndex;
    _layoutStateNotifier = ValueNotifier(
      _BracketLayoutState.stationary(widget.prevColumnIndex),
    );
    _layoutAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(_onLayoutAnimationTick);
    _scrollControllers =
        List.generate(widget.data.length, (index) => ScrollController());
  }

  @override
  void didUpdateWidget(covariant BracketsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isHorizontalTransitioning &&
        oldWidget.prevColumnIndex != widget.prevColumnIndex) {
      _activeColumnIndex = widget.prevColumnIndex;
    }
    if (oldWidget.prevColumnIndex != widget.prevColumnIndex &&
        !_isHorizontalTransitioning) {
      _animateLayoutTo(widget.prevColumnIndex);
    }
    if (oldWidget.data.length != widget.data.length) {
      _resizeScrollControllers();
      if (widget.data.isNotEmpty && _activeColumnIndex >= widget.data.length) {
        _activeColumnIndex = widget.data.length - 1;
      }
    }
  }

  void _resizeScrollControllers() {
    final oldControllers = _scrollControllers;
    final retainedCount = oldControllers.length < widget.data.length
        ? oldControllers.length
        : widget.data.length;
    final newControllers = <ScrollController>[
      for (var i = 0; i < retainedCount; i++) oldControllers[i],
      for (var i = retainedCount; i < widget.data.length; i++)
        ScrollController(),
    ];
    for (var i = widget.data.length; i < oldControllers.length; i++) {
      oldControllers[i].dispose();
    }
    _scrollControllers = newControllers;
  }

  void _onPageChanged(int columnIndex) {
    // Synchronize only the newly selected column.
    _scheduleScrollSync(columnIndex);
  }

  int _matchCount(int columnIndex) {
    final matches = widget.data[columnIndex].localScope.dataContext
        .eval(widget.data[columnIndex].matches.data);
    return (matches as List?)?.length ?? 0;
  }

  double _slotExtent(int columnIndex) {
    return widget.data[columnIndex].matches.height *
        _layoutStateNotifier.value.multiplierFor(columnIndex);
  }

  void _onLayoutAnimationTick() {
    final state = _layoutStateNotifier.value;
    _layoutStateNotifier.value = state.copyWith(
      progress:
          Curves.easeInOutCubic.transform(_layoutAnimationController.value),
    );
  }

  void _animateLayoutTo(int targetColumn, {VoidCallback? onComplete}) {
    final current = _layoutStateNotifier.value;
    if (current.toColumnIndex == targetColumn && current.progress == 1) {
      onComplete?.call();
      return;
    }
    _layoutStateNotifier.value = _BracketLayoutState(
      fromColumnIndex: current.toColumnIndex,
      toColumnIndex: targetColumn,
      progress: 0,
    );
    _layoutAnimationController.forward(from: 0).whenComplete(() {
      if (mounted) onComplete?.call();
    });
  }

  void _registerMatchFocus(_BracketMatchKey key, FocusScopeNode node) {
    _matchFocusScopes[key] = node;
  }

  void _unregisterMatchFocus(_BracketMatchKey key, FocusScopeNode node) {
    if (identical(_matchFocusScopes[key], node)) {
      _matchFocusScopes.remove(key);
    }
  }

  void _scheduleScrollSync(int columnIndex) {
    if (!mounted ||
        columnIndex < 0 ||
        columnIndex >= _scrollControllers.length) {
      return;
    }
    _pendingScrollSyncColumn = columnIndex;
    if (_scrollSyncScheduled) return;
    _scrollSyncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollSyncScheduled = false;
      if (!mounted) return;
      final pendingColumn = _pendingScrollSyncColumn;
      _pendingScrollSyncColumn = null;
      if (pendingColumn == null || pendingColumn >= _scrollControllers.length) {
        return;
      }
      final controller = _scrollControllers[pendingColumn];
      if (!controller.hasClients) return;

      _isSynchronizingScrolls = true;
      final position = controller.position;
      final target = _logicalScrollOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 0.5) {
        controller.jumpTo(target);
      }
      _isSynchronizingScrolls = false;
    });
  }

  void _onColumnScroll(int columnIndex, ScrollNotification notification) {
    if (_isSynchronizingScrolls || notification.metrics.axis != Axis.vertical) {
      return;
    }
    if (notification is ScrollUpdateNotification ||
        notification is ScrollEndNotification) {
      _logicalScrollOffset = notification.metrics.pixels;
      if (notification is ScrollUpdateNotification) {
        // Keep every other column's vertical position in sync live, while
        // dragging - not just once a page change lands. Matches the
        // partially-visible neighbor column(s) to the active column's
        // scroll in real time so connector lines/match rows don't desync
        // mid-drag.
        _syncOtherColumns(excluding: columnIndex);
      }
    }
  }

  void _syncOtherColumns({required int excluding}) {
    _isSynchronizingScrolls = true;
    // Sync ALL other columns, not just the adjacent one - this ensures e.g.
    // Semi Finals and Final scroll with 8th Finals and Quarter Finals, so
    // none of them are out of alignment by the time you page onto them.
    for (var i = 0; i < _scrollControllers.length; i++) {
      if (i == excluding) continue;
      final controller = _scrollControllers[i];
      if (!controller.hasClients) continue;
      final position = controller.position;
      final target = _logicalScrollOffset.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((position.pixels - target).abs() > 0.5) {
        controller.jumpTo(target);
      }
    }
    _isSynchronizingScrolls = false;
  }

  void _requestFocusWhenMounted(
    _BracketMatchKey key,
    int requestGeneration, [
    int attempt = 0,
  ]) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || requestGeneration != _focusRequestGeneration) return;
      final scope = _matchFocusScopes[key];
      if (scope == null || scope.context == null) {
        if (attempt < 4) {
          _requestFocusWhenMounted(key, requestGeneration, attempt + 1);
        }
        return;
      }

      if (scope.hasFocus) {
        _focusedMatch = key;
        return;
      }

      FocusNode? target;
      for (final node in scope.descendants) {
        if (node != scope && node.canRequestFocus && node.context != null) {
          target = node;
        }
      }
      (target ?? scope).requestFocus();
      _focusedMatch = key;
    });
  }

  Future<void> _focusMatch(int columnIndex, int requestedMatch) async {
    // Ignore stale completions from repeated remote events.
    final requestGeneration = ++_focusRequestGeneration;
    final count = _matchCount(columnIndex);
    if (count == 0) return;
    final matchIndex = requestedMatch.clamp(0, count - 1);
    final key = _BracketMatchKey(columnIndex, matchIndex);
    _focusedMatch = key;

    final controller = _scrollControllers[columnIndex];
    Future<void>? scrollAnimation;
    if (controller.hasClients) {
      final position = controller.position;
      final desiredOffset = (matchIndex * _slotExtent(columnIndex) -
              position.viewportDimension * 0.35)
          .clamp(position.minScrollExtent, position.maxScrollExtent);
      _logicalScrollOffset = desiredOffset;
      if ((position.pixels - desiredOffset).abs() > 0.5) {
        scrollAnimation = controller.animateTo(
          desiredOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }

    // Focus must react to the key event, not wait for the viewport animation.
    _requestFocusWhenMounted(key, requestGeneration);

    // A card just outside the lazy cache may mount during this scroll. Retry
    // once the latest request's animation completes in that case.
    if (scrollAnimation != null) {
      await scrollAnimation;
    }
    if (!mounted || requestGeneration != _focusRequestGeneration) return;
    _requestFocusWhenMounted(key, requestGeneration);
  }

  bool _moveVertically(int columnIndex, int matchIndex, int direction) {
    final activeMatch = _focusedMatch?.columnIndex == columnIndex
        ? _focusedMatch!.matchIndex
        : matchIndex;
    final targetMatch = activeMatch + direction;
    // Let the outer focus grid handle the column edges.
    if (targetMatch < 0 || targetMatch >= _matchCount(columnIndex)) {
      return false;
    }
    _focusMatch(columnIndex, targetMatch);
    return true;
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    _layoutAnimationController
      ..removeListener(_onLayoutAnimationTick)
      ..dispose();
    _layoutStateNotifier.dispose();
    _pageScopeNode.dispose();
    super.dispose();
  }

  /// Handle LEFT/RIGHT key events to animate PageView.
  /// Match cards set delegateHorizontalNavigation: true, so horizontal keys bubble up here.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (_isHorizontalTransitioning) return KeyEventResult.handled;

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      if (_activeColumnIndex < widget.data.length - 1) {
        _startHorizontalTransition(_activeColumnIndex + 1);
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (_activeColumnIndex > 0) {
        _startHorizontalTransition(_activeColumnIndex - 1);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Changes page and reflows the layout.
  void _startHorizontalTransition(int targetPage) {
    final targetMatch = _focusedMatch?.columnIndex == _activeColumnIndex
        ? _focusedMatch!.matchIndex
        : 0;

    _isHorizontalTransitioning = true;
    _activeColumnIndex = targetPage;
    widget.pageController
        .animateToPage(targetPage,
            duration: const Duration(milliseconds: 180), curve: Curves.easeOut)
        .whenComplete(() {
      if (!mounted) return;
      widget.onPrevColumnIndexChanged?.call(targetPage);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _animateLayoutTo(targetPage, onComplete: () {
          if (!mounted) return;
          _isHorizontalTransitioning = false;
          _focusMatch(targetPage, targetMatch);
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget pageView = PageView.builder(
      padEnds: false,
      controller: widget.pageController,
      physics: Device().isTV
          ? const NeverScrollableScrollPhysics()
          : const PageScrollPhysics(),
      itemCount: widget.data.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, columnIndex) {
        return BracketsColumnPage(
          controller: widget.controller,
          roundData: widget.data[columnIndex],
          columnIndex: columnIndex,
          prevColumnIndex: widget.prevColumnIndex,
          totalColumns: widget.data.length,
          scrollController: _scrollControllers[columnIndex],
          tvRowOffset: widget.tvRowOffset,
          leftEdgePadding: widget.controller.leftEdgePadding,
          rightEdgePadding: widget.controller.rightEdgePadding,
          layoutState: _layoutStateNotifier,
          onScrollNotification: _onColumnScroll,
          registerMatchFocus: _registerMatchFocus,
          unregisterMatchFocus: _unregisterMatchFocus,
          onMoveVertical: _moveVertically,
          onMatchFocused: (key) => _focusedMatch = key,
        );
      },
    );

    // On TV, wrap with FocusScope to catch delegated horizontal key events.
    // Own the node so navigation can scope its search to this bracket's subtree.
    if (Device().isTV) {
      return FocusScope(
        node: _pageScopeNode,
        onKeyEvent: _handleKeyEvent,
        child: pageView,
      );
    }

    return pageView;
  }
}

class BracketsColumnPage extends StatefulWidget {
  final RoundData roundData;
  final int columnIndex;
  final int prevColumnIndex;
  final int totalColumns;
  final BracketController controller;
  final ScrollController scrollController;
  final int tvRowOffset;
  final double? leftEdgePadding;
  final double? rightEdgePadding;
  final ValueListenable<_BracketLayoutState> layoutState;
  final void Function(int columnIndex, ScrollNotification notification)?
      onScrollNotification;
  final void Function(_BracketMatchKey key, FocusScopeNode node)?
      registerMatchFocus;
  final void Function(_BracketMatchKey key, FocusScopeNode node)?
      unregisterMatchFocus;
  final bool Function(int columnIndex, int matchIndex, int direction)?
      onMoveVertical;
  final ValueChanged<_BracketMatchKey>? onMatchFocused;

  const BracketsColumnPage({
    super.key,
    required this.roundData,
    required this.columnIndex,
    required this.prevColumnIndex,
    required this.totalColumns,
    required this.controller,
    required this.scrollController,
    required this.layoutState,
    this.tvRowOffset = 0,
    this.leftEdgePadding,
    this.rightEdgePadding,
    this.onScrollNotification,
    this.registerMatchFocus,
    this.unregisterMatchFocus,
    this.onMoveVertical,
    this.onMatchFocused,
  });

  @override
  State<BracketsColumnPage> createState() => _BracketsColumnPageState();
}

class _BracketsColumnPageState extends State<BracketsColumnPage> {
  late double matchCardHeight;
  List computedMatches = [];
  late SliverChildBuilderDelegate _sliverDelegate;

  @override
  void initState() {
    computedMatches = widget.roundData.localScope.dataContext
        .eval(widget.roundData.matches.data);
    matchCardHeight = widget.roundData.matches.height;
    _sliverDelegate = _createSliverDelegate();
    super.initState();
  }

  @override
  void didUpdateWidget(covariant BracketsColumnPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.roundData, oldWidget.roundData)) {
      computedMatches = widget.roundData.localScope.dataContext
          .eval(widget.roundData.matches.data);
      matchCardHeight = widget.roundData.matches.height;
      _sliverDelegate = _createSliverDelegate();
    }
  }

  SliverChildBuilderDelegate _createSliverDelegate() =>
      SliverChildBuilderDelegate(
        (context, matchIndex) => _buildMatch(context, matchIndex),
        childCount: computedMatches.length,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
      );

  Widget _buildMatch(BuildContext context, int matchIndex) {
    final matchData = computedMatches[matchIndex];
    final matchScope = widget.roundData.localScope.createChildScope();
    matchScope.dataContext
        .addDataContextById(widget.roundData.matches.name, matchData);
    matchScope.dataContext.addDataContextById('matchIndex', matchIndex);
    matchScope.dataContext.addDataContextById('roundIndex', widget.columnIndex);

    final widgetModel = matchScope
        .buildWidgetModelFromDefinition(widget.roundData.matches.template);
    Widget matchWidget = DataScopeWidget(
      scopeManager: matchScope,
      child: matchScope.buildWidgetFromModel(widgetModel),
    );

    final key = _BracketMatchKey(widget.columnIndex, matchIndex);
    if (Device().isTV && widget.registerMatchFocus != null) {
      matchWidget = _BracketMatchFocusTarget(
        key: ValueKey(key),
        matchKey: key,
        onMoveVertical: widget.onMoveVertical,
        onFocused: widget.onMatchFocused,
        focusOrder: TVFocusOrder.withOptions(
          (widget.tvRowOffset + 1 + matchIndex).toDouble(),
          order: widget.columnIndex.toDouble(),
          isRowEntryPoint:
              matchIndex == 0 && widget.columnIndex == widget.prevColumnIndex,
          delegateHorizontalNavigation: true,
        ),
        register: widget.registerMatchFocus!,
        unregister: widget.unregisterMatchFocus!,
        child: matchWidget,
      );
    } else if (Device().isTV) {
      // Keep the historic TV traversal when this column is used without the
      // BracketsPage coordinator.
      matchWidget = TVFocusWidget(
        focusOrder: TVFocusOrder.withOptions(
          (widget.tvRowOffset + 1 + matchIndex).toDouble(),
          order: widget.columnIndex.toDouble(),
          isRowEntryPoint: matchIndex == 0,
          delegateHorizontalNavigation: true,
        ),
        child: matchWidget,
      );
    }

    return ValueListenableBuilder<_BracketLayoutState>(
      valueListenable: widget.layoutState,
      child: matchWidget,
      builder: (context, layout, card) => Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          height: matchCardHeight,
          width: MediaQuery.of(context).size.width *
              widget.controller.matchCardWidthFraction,
          child: Container(
            margin: EdgeInsets.only(
              left: widget.controller.connectorLength *
                  layout.leftConnectorProgressFor(widget.columnIndex),
            ),
            child: CustomPaint(
              painter: BracketPainter(
                isTopBracket: widget.columnIndex + 1 == widget.totalColumns
                    ? null
                    : !(matchIndex.isEven),
                showLeftBorder:
                    layout.leftConnectorProgressFor(widget.columnIndex) > 0,
                leftBorderOpacity:
                    layout.leftConnectorProgressFor(widget.columnIndex),
                lineColor: widget.controller.lineColor ?? Colors.black,
                borderColor: widget.controller.borderColor ?? Colors.black,
                lineWidth: widget.controller.lineWidth ?? 2.0,
                borderWidth: widget.controller.borderWidth?.toDouble() ?? 2.0,
                connectorLength: widget.controller.connectorLength,
                columnIndex: widget.columnIndex,
                prevColumnIndex: layout.toColumnIndex,
                spacingMultiplier: layout.multiplierFor(widget.columnIndex),
              ),
              child: card,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // TV: reuse the cached delegate across navigation rebuilds so a
    // prevColumnIndex change doesn't discard the sliver's built-child cache
    // (re-parsing/instantiating every visible tile on every navigation).
    // Mobile builds fresh each frame (unchanged).
    final sliverDelegate =
        Device().isTV ? _sliverDelegate : _createSliverDelegate();

    final double leftPad = widget.leftEdgePadding ?? 0.0;
    final double rightPad = widget.columnIndex == widget.totalColumns - 1
        ? (widget.rightEdgePadding ?? 0.0)
        : 0.0;

    return Padding(
      padding: EdgeInsets.only(left: leftPad, right: rightPad),
      child: ValueListenableBuilder<_BracketLayoutState>(
        valueListenable: widget.layoutState,
        builder: (context, layout, _) {
          final multiplier = layout.multiplierFor(widget.columnIndex);
          final slotExtent = matchCardHeight * multiplier;
          final cardTopOffset = matchCardHeight * (multiplier - 1) / 2;
          return NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              widget.onScrollNotification
                  ?.call(widget.columnIndex, notification);
              return false;
            },
            child: CustomScrollView(
              controller: widget.scrollController,
              physics: const ClampingScrollPhysics(),
              cacheExtent: matchCardHeight * 2,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.only(
                      top: cardTopOffset, bottom: cardTopOffset),
                  sliver: SliverFixedExtentList(
                    itemExtent: slotExtent,
                    delegate: sliverDelegate,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Interpolates bracket-tree geometry during reflow.
class _BracketLayoutState {
  const _BracketLayoutState({
    required this.fromColumnIndex,
    required this.toColumnIndex,
    required this.progress,
  });

  factory _BracketLayoutState.stationary(int columnIndex) =>
      _BracketLayoutState(
        fromColumnIndex: columnIndex,
        toColumnIndex: columnIndex,
        progress: 1,
      );

  final int fromColumnIndex;
  final int toColumnIndex;
  final double progress;

  _BracketLayoutState copyWith({double? progress}) => _BracketLayoutState(
        fromColumnIndex: fromColumnIndex,
        toColumnIndex: toColumnIndex,
        progress: progress ?? this.progress,
      );

  double multiplierFor(int columnIndex) {
    double multiplierForAnchor(int anchor) {
      final distance = columnIndex - anchor;
      return distance > 0 ? (1 << distance).toDouble() : 1;
    }

    final from = multiplierForAnchor(fromColumnIndex);
    final to = multiplierForAnchor(toColumnIndex);
    return from + (to - from) * progress;
  }

  double leftConnectorProgressFor(int columnIndex) {
    final from = fromColumnIndex < columnIndex ? 1.0 : 0.0;
    final to = toColumnIndex < columnIndex ? 1.0 : 0.0;
    return from + (to - from) * progress;
  }
}

class _BracketMatchKey {
  const _BracketMatchKey(this.columnIndex, this.matchIndex);

  final int columnIndex;
  final int matchIndex;

  @override
  bool operator ==(Object other) =>
      other is _BracketMatchKey &&
      other.columnIndex == columnIndex &&
      other.matchIndex == matchIndex;

  @override
  int get hashCode => Object.hash(columnIndex, matchIndex);
}

/// Lightweight per-card TV focus boundary.
class _BracketMatchFocusTarget extends StatefulWidget {
  const _BracketMatchFocusTarget({
    super.key,
    required this.matchKey,
    required this.register,
    required this.unregister,
    required this.child,
    required this.focusOrder,
    this.onMoveVertical,
    this.onFocused,
  });

  final _BracketMatchKey matchKey;
  final void Function(_BracketMatchKey key, FocusScopeNode node) register;
  final void Function(_BracketMatchKey key, FocusScopeNode node) unregister;
  final TVFocusOrder focusOrder;
  final bool Function(int columnIndex, int matchIndex, int direction)?
      onMoveVertical;
  final ValueChanged<_BracketMatchKey>? onFocused;
  final Widget child;

  @override
  State<_BracketMatchFocusTarget> createState() =>
      _BracketMatchFocusTargetState();
}

class _BracketMatchFocusTargetState extends State<_BracketMatchFocusTarget> {
  late final FocusScopeNode _scopeNode = FocusScopeNode(
    debugLabel:
        'BracketMatch(${widget.matchKey.columnIndex}, ${widget.matchKey.matchIndex})',
  );

  @override
  void initState() {
    super.initState();
    widget.register(widget.matchKey, _scopeNode);
  }

  @override
  void dispose() {
    widget.unregister(widget.matchKey, _scopeNode);
    _scopeNode.dispose();
    super.dispose();
  }

  KeyEventResult _onKeyEvent(FocusNode _, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      final didMove = widget.onMoveVertical
          ?.call(widget.matchKey.columnIndex, widget.matchKey.matchIndex, -1);
      return didMove == true ? KeyEventResult.handled : KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      widget.onMoveVertical
          ?.call(widget.matchKey.columnIndex, widget.matchKey.matchIndex, 1);
      // At the final card, keep focus in this column. Letting DOWN bubble into
      // the outer focus grid can select a card in a different-length column.
      return KeyEventResult.handled;
    }
    // LEFT/RIGHT deliberately bubble to BracketsPage's FocusScope.
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => TVFocusWidget(
        focusOrder: widget.focusOrder,
        primaryFocusNode: _scopeNode,
        child: FocusScope(
          node: _scopeNode,
          onKeyEvent: _onKeyEvent,
          onFocusChange: (hasFocus) {
            if (!hasFocus) return;
            widget.onFocused?.call(widget.matchKey);
            if (_scopeNode.hasPrimaryFocus) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_scopeNode.hasPrimaryFocus) return;
                for (final node in _scopeNode.descendants) {
                  if (node != _scopeNode &&
                      node.canRequestFocus &&
                      node.context != null) {
                    node.requestFocus();
                  }
                }
              });
            }
          },
          child: widget.child,
        ),
      );
}

/// Paints bracket connector lines between tournament matches.
///
/// Draws:
/// - Border rectangle around the match card
/// - Right-side horizontal + vertical connector (toward next round)
/// - Left-side horizontal connector (from previous round)
///
/// [columnIndex] - The index of the current column being rendered.
/// [prevColumnIndex] - The index of the currently focused/visible page.
/// [spacingMultiplier] - Live interpolated spacing from [_BracketLayoutState],
/// used during a column transition; falls back to [prevColumnIndex] when unset.
/// Used to calculate dynamic vertical line length when columns are "expanded"
/// (i.e., when viewing later rounds where card spacing increases).
class BracketPainter extends CustomPainter {
  // Baseline connector length used as default
  static const _baselineConnectorLength = 25.0;

  final bool? isTopBracket;
  final bool showLeftBorder;
  final Color lineColor;
  final double lineWidth;
  final Color borderColor;
  final double borderWidth;
  final double connectorLength;
  final int columnIndex;
  final int prevColumnIndex;
  final double? spacingMultiplier;
  final double leftBorderOpacity;

  BracketPainter({
    this.isTopBracket,
    required this.showLeftBorder,
    this.lineColor = Colors.black,
    this.lineWidth = 2.0,
    this.borderColor = Colors.black,
    this.borderWidth = 2.0,
    this.connectorLength = _baselineConnectorLength,
    this.columnIndex = 0,
    this.prevColumnIndex = 0,
    this.spacingMultiplier,
    this.leftBorderOpacity = 1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, borderPaint);

    if (isTopBracket != null) {
      final startPoint = Offset(size.width, size.height / 2);
      final endPoint = Offset(size.width + connectorLength, size.height / 2);
      canvas.drawLine(startPoint, endPoint, linePaint);

      final verticalStartPoint = endPoint;
      // Calculate vertical line length based on card spacing.
      // Cards double in spacing with each column distance; vertical line
      // needs to reach halfway to the adjacent card.
      final cardHeight = size.height;
      double verticalLength;
      if (spacingMultiplier != null) {
        // Live-interpolated spacing during a column transition.
        verticalLength = cardHeight * 0.5 * spacingMultiplier!;
      } else if (prevColumnIndex < columnIndex) {
        // When expanded, cards have gaps - use spacing multiplier.
        final distance = columnIndex - prevColumnIndex;
        final multiplier = 1 << distance; // 2^distance
        verticalLength = cardHeight * 0.5 * multiplier;
      } else {
        // Non-expanded: cards stacked with no gap, use half card height.
        verticalLength = cardHeight * 0.5;
      }
      final verticalEndPoint = isTopBracket!
          ? Offset(endPoint.dx, endPoint.dy - verticalLength)
          : Offset(endPoint.dx, endPoint.dy + verticalLength);
      canvas.drawLine(verticalStartPoint, verticalEndPoint, linePaint);
    }
    if (showLeftBorder && leftBorderOpacity > 0) {
      final leftStartPoint = Offset(0, size.height / 2);
      final leftEndPoint = Offset(-connectorLength, size.height / 2);
      final leftLinePaint = Paint()
        ..color = lineColor.withValues(alpha: leftBorderOpacity)
        ..strokeWidth = lineWidth
        ..style = PaintingStyle.stroke;
      canvas.drawLine(leftStartPoint, leftEndPoint, leftLinePaint);
    }
  }

  @override
  bool shouldRepaint(covariant BracketPainter oldDelegate) =>
      oldDelegate.columnIndex != columnIndex ||
      oldDelegate.prevColumnIndex != prevColumnIndex ||
      oldDelegate.spacingMultiplier != spacingMultiplier ||
      oldDelegate.leftBorderOpacity != leftBorderOpacity ||
      oldDelegate.isTopBracket != isTopBracket ||
      oldDelegate.showLeftBorder != showLeftBorder ||
      oldDelegate.connectorLength != connectorLength ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.lineWidth != lineWidth ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}

/// TV focus provider for the Bracket widget.
///
/// Horizontal navigation is handled by:
/// 1. Match cards set delegateHorizontalNavigation: true in YAML
/// 2. BracketsPage FocusScope catches LEFT/RIGHT keys and animates PageView
class _BracketTVFocusProvider implements TVFocusProvider {
  // Singleton - no state needed
  static final _instance = _BracketTVFocusProvider._();
  factory _BracketTVFocusProvider() => _instance;
  _BracketTVFocusProvider._();

  @override
  Widget wrapFocusable({
    required double row,
    required double order,
    required Widget child,
    bool isRowEntryPoint = false,
    bool lockHorizontalNavigation = false,
    bool delegateHorizontalNavigation = false,
    String? focusGroup,
    bool rememberRowPosition = false,
    FocusNode? primaryFocusNode,
    KeyEventResult Function(FocusNode node)? onBackPressed,
    VoidCallback? onRightEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onTopEdge,
    VoidCallback? onBottomEdge,
  }) {
    // DON'T wrap with TVFocusWidget - bracket.dart already handles TV navigation.
    // box_wrapper has already applied focus styling (backgroundColor, focusBorderColor, etc.)
    // from YAML tvOptions. Just return the styled child as-is.
    return child;
  }

  /// The bracket handles horizontal scrolling via PageView page changes.
  /// This prevents box_wrapper from calling Scrollable.ensureVisible()
  /// which would cause horizontal jerk when navigating UP/DOWN.
  @override
  bool get handlesHorizontalScroll => true;

  @override
  double get rowOffset => 0;

  @override
  double get orderOffset => 0;

  @override
  Color? get focusBorderColor => null;

  @override
  double? get focusBorderWidth => null;

  @override
  double? get focusBorderRadius => 0;

  @override
  int? get focusAnimationDurationMs => null;

  @override
  void dispose() {}

  @override
  void requestFocusAt(BuildContext context, double row,
      [double? order, String? focusGroup]) {
    const TVFocusOrder(0).requestFocusAt(context, row, order, focusGroup);
  }

  @override
  void requestFocusByEdge(
    BuildContext context, {
    required TVFocusDirection direction,
    String? targetFocusGroup,
    double? targetRow,
    double? targetOrder,
    double? currentRow,
    double? currentOrder,
  }) {
    const TVFocusOrder(0).requestFocusByEdge(
      context,
      direction: direction,
      targetFocusGroup: targetFocusGroup,
      targetRow: targetRow,
      targetOrder: targetOrder,
      currentRow: currentRow,
      currentOrder: currentOrder,
    );
  }

  // Bracket handles its own TV navigation and has no row-position memory.
  @override
  void saveRowPosition({
    required ModalRoute<dynamic>? route,
    required double row,
    required double order,
    String? focusGroup,
  }) {}
}
