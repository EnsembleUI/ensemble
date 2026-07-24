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

  // Computed layout values based on scale
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
        tabPadding = Utils.optionalInsets(data['padding']);
        tabGap = Utils.getDouble(data['gap'], fallback: 12.0);
        // Focus styling (TV D-pad)
        // Priority: focusBorderColor > Theme > Provider > borderColor > app primary
        // Priority: focusBorderWidth > Theme > Provider > borderWidth > default (2.0)
        // Priority: focusBorderRadius > Theme > Provider > borderRadius > default (8.0)
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
  // Keep FocusTraversalGroup stable across rebuilds - must be at this level
  // because BracketsView is recreated when roundData changes
  final _focusTraversalGroupKey = GlobalKey();

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
      focusTraversalGroupKey: _focusTraversalGroupKey,
      tvRowOffset: widget.controller.tvRowOffset,
    );
  }
}

class BracketsView extends StatefulWidget {
  final List<RoundData> data;
  final BracketController controller;
  final GlobalKey? focusTraversalGroupKey;
  final int tvRowOffset;

  const BracketsView({
    super.key,
    required this.data,
    required this.controller,
    this.focusTraversalGroupKey,
    this.tvRowOffset = 0,
  });

  @override
  State<BracketsView> createState() => _BracketsViewState();
}

class _BracketsViewState extends State<BracketsView> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  // Tracks the target page for animation - controls column expansion
  int _prevColumnIndex = 0;
  List<GlobalKey> _tabKeys = [];
  // Provider to tell children that bracket handles horizontal scrolling
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
    // Only regenerate if data length changed
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
            padding: EdgeInsets.zero,
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: List.generate(widget.data.length, (index) {
                bool isSelected = index == _currentPageIndex;
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
                      shape: widget.controller.tabBorderRadius != null
                          ? RoundedRectangleBorder(
                              borderRadius:
                                  widget.controller.tabBorderRadius!.getValue(),
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
    // Get focus styling from controller with fallback chain
    // Priority: tabStyles > Theme > Provider > Widget styles > Default (same as box_wrapper.dart)
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

    // Border color: use focus color when focused, transparent otherwise
    // Always render border to prevent size jerk
    final borderColor = _isFocused ? focusBorderColor : Colors.transparent;

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
                  width: focusBorderWidth,
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

class CustomScrollNotification extends Notification {
  final double scrollPosition;
  final double maxScrollExtent;
  final double visibleHeight;

  CustomScrollNotification(
      this.scrollPosition, this.maxScrollExtent, this.visibleHeight);
}

class _BracketsPageState extends State<BracketsPage> {
  late List<ScrollController> _scrollControllers;

  @override
  void initState() {
    super.initState();
    _scrollControllers =
        List.generate(widget.data.length, (index) => ScrollController());
  }

  void _onPageChanged(int index) async {
    // Only animate scroll if controller is attached
    if (index < _scrollControllers.length &&
        _scrollControllers[index].hasClients) {
      _scrollControllers[index].animateTo(0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.decelerate);
      _scrollControllers[index].animateTo(0.1,
          duration: const Duration(milliseconds: 10), curve: Curves.decelerate);
    }

    // Note: prevColumnIndex is managed by parent (_BracketsViewState) and updated:
    // 1. Via _animateToPage when tabs are clicked
    // 2. Via onPrevColumnIndexChanged callback when keyboard navigation occurs
    // We don't update it here because onPageChanged fires unreliably with small
    // viewportFraction and padEnds=false (doesn't fire for clamped pages like page 3).
  }

  /// Find and focus an item in the current page at the given row.
  /// If the row doesn't exist (e.g., row 8 in Quarter Finals), clamp to available rows.
  void _focusRowInCurrentPage(int targetRow, int columnIndex) {
    // Number of matches in this round determines max row
    final matchCount = widget.data[columnIndex].matches.data;
    final evalData =
        widget.data[columnIndex].localScope.dataContext.eval(matchCount);
    final numMatches = (evalData as List?)?.length ?? 1;

    // Clamp targetRow to available match rows
    // Tabs are at tvRowOffset, matches start at tvRowOffset + 1
    final matchRowStart = widget.tvRowOffset + 1;
    final clampedRow =
        targetRow.clamp(matchRowStart, matchRowStart + numMatches - 1);

    // Find the focusable item with this row and column (order)
    // We find the DEEPEST focusable descendant that has this TVFocusOrder,
    // as this corresponds to the innermost Focus widget with visual styling.
    final root = FocusManager.instance.rootScope;
    FocusNode? bestMatch;
    int bestDepth = -1;

    for (final focusNode in root.descendants) {
      if (focusNode.context == null) continue;

      final focusTraversalOrder = focusNode.context
          ?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final order = focusTraversalOrder!.order as TVFocusOrder;

        // Match by row and order (column = roundIndex)
        if (order.row.toInt() == clampedRow &&
            order.order.toInt() == columnIndex) {
          // Calculate depth of this node (deeper = better for visual styling)
          int depth = 0;
          FocusNode? parent = focusNode.parent;
          while (parent != null) {
            depth++;
            parent = parent.parent;
          }

          if (depth > bestDepth) {
            bestDepth = depth;
            bestMatch = focusNode;
          }
        }
      }
    }

    if (bestMatch != null) {
      bestMatch.requestFocus();
    }
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Handle LEFT/RIGHT key events to animate PageView.
  /// Match cards set delegateHorizontalNavigation: true, so horizontal keys bubble up here.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Use widget.prevColumnIndex instead of pageController.page because with small viewportFraction
    // and padEnds=false, pageController.page gets clamped (e.g., max 1.5 with 4 pages at 0.4 fraction)
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final currentPage = widget.prevColumnIndex;
      if (currentPage < widget.data.length - 1) {
        final focusRow = _getCurrentFocusedRow(node);
        final targetPage = currentPage + 1;

        // Notify parent to update prevColumnIndex BEFORE animation starts.
        // This ensures correct navigation even if onPageChanged doesn't fire (clamped pages).
        widget.onPrevColumnIndexChanged?.call(targetPage);

        widget.pageController
            .animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
            .then((_) {
          // After animation completes, transfer focus to the new page
          if (focusRow != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusRowInCurrentPage(focusRow, targetPage);
            });
          }
        });
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final currentPage = widget.prevColumnIndex;
      if (currentPage > 0) {
        final focusRow = _getCurrentFocusedRow(node);
        final targetPage = currentPage - 1;

        // Notify parent to update prevColumnIndex BEFORE animation starts.
        // This ensures correct navigation even if onPageChanged doesn't fire (clamped pages).
        widget.onPrevColumnIndexChanged?.call(targetPage);

        widget.pageController
            .animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        )
            .then((_) {
          // After animation completes, transfer focus to the new page
          if (focusRow != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _focusRowInCurrentPage(focusRow, targetPage);
            });
          }
        });
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  /// Extract the current focused row from the TVFocusOrder in the focus tree.
  int? _getCurrentFocusedRow(FocusNode node) {
    // Use primaryFocus instead of the passed node, because the passed node
    // is the FocusScope's node, not the actually focused child
    FocusNode? current = FocusManager.instance.primaryFocus;
    while (current != null) {
      final context = current.context;
      if (context != null) {
        final focusTraversalOrder =
            context.findAncestorWidgetOfExactType<FocusTraversalOrder>();
        if (focusTraversalOrder?.order is TVFocusOrder) {
          final order = focusTraversalOrder!.order as TVFocusOrder;
          // Return the row as-is (matches are at tvRowOffset + 1 + matchIndex)
          return order.row.toInt();
        }
      }
      current = current.parent;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    Widget pageView = NotificationListener<CustomScrollNotification>(
      onNotification: (CustomScrollNotification notification) {
        int currentPage = widget.pageController.page?.round() ?? 0;
        // Sync scroll to ALL columns after the current one (not just the next)
        // This ensures Semi Finals and Final scroll with 8th Finals and Quarter Finals
        for (int i = currentPage + 1; i < _scrollControllers.length; i++) {
          if (_scrollControllers[i].hasClients) {
            _scrollControllers[i].jumpTo(notification.scrollPosition);
          }
        }
        return true;
      },
      child: PageView.builder(
        padEnds: false,
        controller: widget.pageController,
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
          );
        },
      ),
    );

    // On TV, wrap with FocusScope to catch delegated horizontal key events
    if (Device().isTV) {
      return FocusScope(
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

  const BracketsColumnPage({
    super.key,
    required this.roundData,
    required this.columnIndex,
    required this.prevColumnIndex,
    required this.totalColumns,
    required this.controller,
    required this.scrollController,
    this.tvRowOffset = 0,
  });

  @override
  State<BracketsColumnPage> createState() => _BracketsColumnPageState();
}

class _BracketsColumnPageState extends State<BracketsColumnPage> {
  late double matchCardHeight;
  List computedMatches = [];

  @override
  void initState() {
    computedMatches = widget.roundData.localScope.dataContext
        .eval(widget.roundData.matches.data);
    matchCardHeight = widget.roundData.matches.height;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
      onNotification: (ScrollNotification notification) {
        if (notification is ScrollUpdateNotification) {
          double visibleHeight = notification.metrics.viewportDimension;
          CustomScrollNotification(
            notification.metrics.pixels,
            notification.metrics.maxScrollExtent,
            visibleHeight,
          ).dispatch(context);
        }
        return true;
      },
      child: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        physics: const ClampingScrollPhysics(),
        controller: widget.scrollController,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...computedMatches.asMap().entries.map((entry) {
              final matchIndex = entry.key;
              final matchData = entry.value;

              // Calculate vertical MARGIN to center cards between previous column's matches
              // Uses prevColumnIndex for animation effect - stages "expand" as you navigate to them
              //
              // Key insight: In a Column, margin.top is RELATIVE to the previous element,
              // not an absolute position from the top. So we need:
              // - Match 0: margin = initialOffset (where to start from top)
              // - Match i > 0: margin = gap between cards
              //
              // Where: initialOffset = cardHeight * 0.5 * (multiplier - 1)
              //        gap = cardHeight * (multiplier - 1)
              double topOffset = 0;
              if (widget.prevColumnIndex < widget.columnIndex) {
                final distance = widget.columnIndex - widget.prevColumnIndex;
                final multiplier = 1 << distance; // 2^distance
                if (matchIndex == 0) {
                  // First match: position from top of container
                  topOffset = matchCardHeight * 0.5 * (multiplier - 1);
                } else {
                  // Subsequent matches: gap between cards (relative to previous)
                  topOffset = matchCardHeight * (multiplier - 1);
                }
              }

              // Create a CHILD scope for each match
              final matchScope = widget.roundData.localScope.createChildScope();
              matchScope.dataContext
                  .addDataContextById(widget.roundData.matches.name, matchData);
              matchScope.dataContext
                  .addDataContextById('matchIndex', matchIndex);
              matchScope.dataContext
                  .addDataContextById('roundIndex', widget.columnIndex);

              // Build the widget model and widget, then wrap in DataScopeWidget
              // This allows the widget to access the scope's data context for expressions
              final widgetModel = matchScope.buildWidgetModelFromDefinition(
                  widget.roundData.matches.template);
              final templatedWidget =
                  matchScope.buildWidgetFromModel(widgetModel);
              final cellWidget = DataScopeWidget(
                scopeManager: matchScope,
                child: templatedWidget,
              );

              // Wrap with TVFocusWidget directly in Dart (not via YAML tvOptions)
              // This avoids scope evaluation timing issues - matchIndex/roundIndex
              // are available here but not during YAML re-evaluation on rebuild.
              // Note: Don't add extra Focus widget here - let box_wrapper's Focus
              // handle visual styling. TVFocusWidget only provides ordering.
              Widget matchWidget = cellWidget;
              if (Device().isTV) {
                matchWidget = TVFocusWidget(
                  focusOrder: TVFocusOrder.withOptions(
                    (widget.tvRowOffset + 1 + matchIndex)
                        .toDouble(), // matches start at tvRowOffset + 1
                    order: widget.columnIndex.toDouble(), // column = roundIndex
                    isRowEntryPoint:
                        matchIndex == 0, // first match is entry point
                    delegateHorizontalNavigation:
                        true, // let bracket handle LEFT/RIGHT
                  ),
                  child: matchWidget,
                );
              }

              return AnimatedContainer(
                height: matchCardHeight,
                width: MediaQuery.of(context).size.width *
                    widget.controller.matchCardWidthFraction,
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(
                    top: topOffset,
                    // Left margin animates with navigation - expands when moving forward, collapses when moving back
                    left: widget.prevColumnIndex < widget.columnIndex
                        ? widget.controller.connectorLength
                        : 0),
                child: CustomPaint(
                  painter: BracketPainter(
                    isTopBracket: widget.columnIndex + 1 == widget.totalColumns
                        ? null
                        : !(matchIndex % 2 == 0),
                    // Uses prevColumnIndex for animation - left line appears as you navigate forward
                    showLeftBorder: widget.prevColumnIndex < widget.columnIndex,
                    lineColor: widget.controller.lineColor ?? Colors.black,
                    borderColor: widget.controller.borderColor ?? Colors.black,
                    lineWidth: widget.controller.lineWidth ?? 2.0,
                    borderWidth:
                        widget.controller.borderWidth?.toDouble() ?? 2.0,
                    connectorLength: widget.controller.connectorLength,
                    columnIndex: widget.columnIndex,
                    prevColumnIndex: widget.prevColumnIndex,
                  ),
                  child: matchWidget,
                ),
              );
            }),
            // Add bottom padding to equalize content heights across columns
            // This ensures all columns can scroll together without one running out of content
            // Bottom padding = first match's top margin = cardHeight * 0.5 * (multiplier - 1)
            if (widget.prevColumnIndex < widget.columnIndex) ...[
              Builder(builder: (context) {
                final distance = widget.columnIndex - widget.prevColumnIndex;
                final multiplier = 1 << distance;
                final bottomPadding = matchCardHeight * 0.5 * (multiplier - 1);
                return SizedBox(height: bottomPadding);
              }),
            ],
          ],
        ),
      ),
    );
  }
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
      // Calculate vertical line length based on card spacing
      // Cards double in spacing with each column distance
      // Vertical line needs to reach halfway to the adjacent card
      final cardHeight = size.height;
      double verticalLength;
      if (prevColumnIndex < columnIndex) {
        // When expanded, cards have gaps - use spacing multiplier
        final distance = columnIndex - prevColumnIndex;
        final multiplier = 1 << distance; // 2^distance
        verticalLength = cardHeight * 0.5 * multiplier;
      } else {
        // Non-expanded: cards stacked with no gap, use half card height
        verticalLength = cardHeight * 0.5;
      }
      final verticalEndPoint = isTopBracket!
          ? Offset(endPoint.dx, endPoint.dy - verticalLength)
          : Offset(endPoint.dx, endPoint.dy + verticalLength);
      canvas.drawLine(verticalStartPoint, verticalEndPoint, linePaint);
    }
    if (showLeftBorder) {
      final leftStartPoint = Offset(0, size.height / 2);
      final leftEndPoint = Offset(-connectorLength, size.height / 2);
      canvas.drawLine(leftStartPoint, leftEndPoint, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant BracketPainter oldDelegate) =>
      oldDelegate.columnIndex != columnIndex ||
      oldDelegate.prevColumnIndex != prevColumnIndex ||
      oldDelegate.isTopBracket != isTopBracket ||
      oldDelegate.showLeftBorder != showLeftBorder ||
      oldDelegate.connectorLength != connectorLength ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.lineWidth != lineWidth ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}

/// Simple TV focus provider for the Bracket widget.
/// Only purpose: Set handlesHorizontalScroll = true to prevent horizontal jerk
/// when navigating UP/DOWN (stops box_wrapper from calling Scrollable.ensureVisible).
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
}
