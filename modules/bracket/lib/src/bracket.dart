// ignore_for_file: avoid_print

import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/stub/ensemble_bracket.dart';
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

class EnsembleBracketImpl extends EnsembleWidget<BracketController>
    implements EnsembleBracket {
  const EnsembleBracketImpl._(super.controller);

  factory EnsembleBracketImpl.build([dynamic controller]) =>
      EnsembleBracketImpl._(
          controller is BracketController ? controller : BracketController());

  @override
  State<StatefulWidget> createState() => BracketState();
}

class RoundTemplate extends ItemTemplate {
  final String? title;
  final MatchTemplate matches;

  RoundTemplate({
    required String? data,
    required String name,
    dynamic template,
    required this.title,
    required this.matches,
  }) : super(data, name, template);
}

class MatchTemplate extends ItemTemplate {
  final double height;

  MatchTemplate(super.data, super.name, super.template, this.height);
}

class RoundData {
  final String title;
  final MatchTemplate matches;
  final ScopeManager localScope;

  RoundData({
    required this.title,
    required this.matches,
    required this.localScope,
  });
}

class BracketController extends EnsembleBoxController {
  EdgeInsets? tabPadding;

  double tabGap = 12;

  BracketController();

  RoundTemplate? roundTemplate;
  Color? lineColor;
  double? lineWidth;

  Color? tabBackgroundColor;
  Color? tabSelectedBackgroundColor;
  TextStyle? tabTextStyle;
  TextStyle? tabSelectedStyle;
  EBorderRadius? tabBorderRadius;

  // Tab focus styling (TV D-pad)
  Color? tabFocusColor;
  double? tabFocusBorderWidth;
  EBorderRadius? tabFocusBorderRadius;
  int? tabFocusAnimationDurationMs;
  Color? tabFocusBackgroundColor;
  TextStyle? tabFocusTextStyle;

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
        tabPadding = Utils.optionalInsets(data['padding']);
        tabGap = Utils.getDouble(data['gap'], fallback: 12.0);
        // Focus styling (TV D-pad)
        tabFocusColor = Utils.getColor(data['focusColor']);
        tabFocusBorderWidth = Utils.optionalDouble(data['focusBorderWidth']);
        tabFocusBorderRadius = Utils.getBorderRadius(data['focusBorderRadius']);
        tabFocusAnimationDurationMs = Utils.optionalInt(data['focusAnimationDurationMs']);
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
              Utils.optionalString(data['item-template']['name']) ?? 'march',
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

  _buildRoundConfig(BuildContext context, List dataList) {
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
    );
  }
}

class BracketsView extends StatefulWidget {
  final List<RoundData> data;
  final BracketController controller;
  final GlobalKey? focusTraversalGroupKey;

  const BracketsView({
    super.key,
    required this.data,
    required this.controller,
    this.focusTraversalGroupKey,
  });

  @override
  State<BracketsView> createState() => _BracketsViewState();
}

class _BracketsViewState extends State<BracketsView> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  List<GlobalKey> _tabKeys = [];
  // Provider to tell children that bracket handles horizontal scrolling
  final _bracketTVFocusProvider = _BracketTVFocusProvider();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.75);
    _pageController.addListener(_updatePageIndex);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tabKeys =
        List<GlobalKey>.generate(widget.data.length, (index) => GlobalKey());
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
      Scrollable.ensureVisible(
        _tabKeys[index].currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5,
      );
    }
  }

  void _animateToPage(int index) {
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
                  ),
                )
              : BracketsPage(
                  controller: widget.controller,
                  pageController: _pageController,
                  data: widget.data,
                ),
        ),
      ],
    );

    // Wrap with FocusTraversalGroup for TV D-pad navigation
    // This allows tabs (row 0) and matches (row 1+) to navigate between each other
    if (Device().isTV) {
      content = FocusTraversalGroup(
        key: widget.focusTraversalGroupKey, // Key from parent to stay stable across rebuilds
        policy: TVFocusOrderTraversalPolicy(),
        child: content,
      );
    }

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
  final VoidCallback onPressed;

  const _TVTabButton({
    required this.tabKey,
    required this.index,
    required this.title,
    required this.isSelected,
    required this.controller,
    required this.onPressed,
  });

  @override
  State<_TVTabButton> createState() => _TVTabButtonState();
}

class _TVTabButtonState extends State<_TVTabButton> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    // Get focus styling from controller or use defaults
    final focusBorderColor = widget.controller.tabFocusColor ?? Colors.white;
    final focusBorderWidth = widget.controller.tabFocusBorderWidth ?? 3.0;
    final borderRadius = widget.controller.tabFocusBorderRadius?.getValue() ??
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
        0, // Row 0 for tab bar
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

  const BracketsPage({
    super.key,
    required this.data,
    required this.pageController,
    required this.controller,
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
  int _prevColumnIndex = 0;
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
          duration: const Duration(milliseconds: 600), curve: Curves.decelerate);
      _scrollControllers[index].animateTo(0.1,
          duration: const Duration(milliseconds: 10), curve: Curves.decelerate);
    }

    setState(() {
      _prevColumnIndex = index;
    });
    // Focus transfer is handled in _handleKeyEvent after animation completes
  }

  /// Find and focus an item in the current page at the given row.
  /// If the row doesn't exist (e.g., row 8 in Quarter Finals), clamp to available rows.
  void _focusRowInCurrentPage(int targetRow, int columnIndex) {
    // Number of matches in this round determines max row
    final matchCount = widget.data[columnIndex].matches.data;
    final evalData = widget.data[columnIndex].localScope.dataContext.eval(matchCount);
    final numMatches = (evalData as List?)?.length ?? 1;

    // Clamp targetRow to available rows (1 to numMatches)
    final clampedRow = targetRow.clamp(1, numMatches);

    // Find the focusable item with this row and column (order)
    final root = FocusManager.instance.rootScope;
    for (final focusNode in root.descendants) {
      if (focusNode.context == null) continue;

      final focusTraversalOrder =
          focusNode.context?.findAncestorWidgetOfExactType<FocusTraversalOrder>();
      if (focusTraversalOrder?.order is TVFocusOrder) {
        final order = focusTraversalOrder!.order as TVFocusOrder;
        // Match by row and order (column = roundIndex)
        if (order.row.toInt() == clampedRow && order.order.toInt() == columnIndex) {
          focusNode.requestFocus();
          return;
        }
      }
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

    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      final currentPage = widget.pageController.page?.round() ?? 0;
      if (currentPage < widget.data.length - 1) {
        // Get current focused row to restore after page change
        final focusRow = _getCurrentFocusedRow(node);
        final targetPage = currentPage + 1;
        widget.pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ).then((_) {
          // After animation completes, transfer focus to the new page
          if (focusRow != null) {
            _focusRowInCurrentPage(focusRow, targetPage);
          }
        });
        return KeyEventResult.handled;
      }
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      final currentPage = widget.pageController.page?.round() ?? 0;
      if (currentPage > 0) {
        // Get current focused row to restore after page change
        final focusRow = _getCurrentFocusedRow(node);
        final targetPage = currentPage - 1;
        widget.pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ).then((_) {
          // After animation completes, transfer focus to the new page
          if (focusRow != null) {
            _focusRowInCurrentPage(focusRow, targetPage);
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
          // Row is 1-indexed (matchIndex + 1), so return as int
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
        // Only sync scroll if next page exists and controller is attached
        final nextPageIndex = currentPage + 1;
        if (nextPageIndex < _scrollControllers.length &&
            _scrollControllers[nextPageIndex].hasClients) {
          _scrollControllers[nextPageIndex].jumpTo(notification.scrollPosition);
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
            prevColumnIndex: _prevColumnIndex,
            totalColumns: widget.data.length,
            scrollController: _scrollControllers[columnIndex],
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

  const BracketsColumnPage({
    super.key,
    required this.roundData,
    required this.columnIndex,
    required this.prevColumnIndex,
    required this.totalColumns,
    required this.controller,
    required this.scrollController,
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
    bool isNextColumn = widget.columnIndex == widget.prevColumnIndex + 1;

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

              double topOffset = 0;
              if (widget.prevColumnIndex < widget.columnIndex) {
                topOffset = topOffset + (matchCardHeight / 2);
                if (matchIndex > 0) {
                  topOffset = topOffset + matchCardHeight / 2;
                }
              }

              // Create a CHILD scope for each match
              final matchScope = widget.roundData.localScope.createChildScope();
              matchScope.dataContext
                  .addDataContextById(widget.roundData.matches.name, matchData);
              matchScope.dataContext.addDataContextById('matchIndex', matchIndex);
              matchScope.dataContext.addDataContextById('roundIndex', widget.columnIndex);

              final cellWidget =
                  matchScope.buildWidgetFromDefinition(widget.roundData.matches.template);

              return AnimatedContainer(
                height: matchCardHeight,
                width: MediaQuery.of(context).size.width * 0.6,
                duration: const Duration(milliseconds: 300),
                margin: EdgeInsets.only(
                    top: topOffset, left: !isNextColumn ? 0 : 15),
                child: CustomPaint(
                  painter: BracketPainter(
                    isTopBracket: widget.columnIndex + 1 == widget.totalColumns
                        ? null
                        : !(matchIndex % 2 == 0),
                    showLeftBorder: widget.prevColumnIndex < widget.columnIndex,
                    lineColor: widget.controller.lineColor ?? Colors.black,
                    borderColor: widget.controller.borderColor ?? Colors.black,
                    lineWidth: widget.controller.lineWidth ?? 2.0,
                    borderWidth:
                        widget.controller.borderWidth?.toDouble() ?? 2.0,
                  ),
                  child: cellWidget,
                ),
              );
            }),
            if (isNextColumn) SizedBox(height: matchCardHeight),
          ],
        ),
      ),
    );
  }
}

class BracketPainter extends CustomPainter {
  final bool? isTopBracket;
  final bool showLeftBorder;
  final Color lineColor;
  final double lineWidth;
  final Color borderColor;
  final double borderWidth;

  BracketPainter({
    this.isTopBracket,
    required this.showLeftBorder,
    this.lineColor = Colors.black,
    this.lineWidth = 2.0,
    this.borderColor = Colors.black,
    this.borderWidth = 2.0,
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
      final endPoint = Offset(size.width + 25, size.height / 2);
      canvas.drawLine(startPoint, endPoint, linePaint);

      const double verticalLength = 40;
      final verticalStartPoint = endPoint;
      final verticalEndPoint = isTopBracket!
          ? Offset(endPoint.dx, endPoint.dy - verticalLength)
          : Offset(endPoint.dx, endPoint.dy + verticalLength);
      canvas.drawLine(verticalStartPoint, verticalEndPoint, linePaint);
    }
    if (showLeftBorder) {
      final leftStartPoint = Offset(0, size.height / 2);
      final leftEndPoint = Offset(-25, size.height / 2);
      canvas.drawLine(leftStartPoint, leftEndPoint, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
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
    KeyEventResult Function(FocusNode node)? onBackPressed,
    VoidCallback? onRightEdge,
    VoidCallback? onLeftEdge,
    VoidCallback? onTopEdge,
    VoidCallback? onBottomEdge,
  }) {
    // Just wrap with TVFocusWidget - no special handling needed
    // delegateHorizontalNavigation from YAML will bubble up to BracketsPage FocusScope
    return TVFocusWidget(
      focusOrder: TVFocusOrder.withOptions(
        row,
        order: order,
        isRowEntryPoint: isRowEntryPoint,
        lockHorizontalNavigation: lockHorizontalNavigation,
        delegateHorizontalNavigation: delegateHorizontalNavigation,
      ),
      onBackPressed: onBackPressed,
      onRightEdge: onRightEdge,
      onLeftEdge: onLeftEdge,
      onTopEdge: onTopEdge,
      onBottomEdge: onBottomEdge,
      child: child,
    );
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
  Color? get focusColor => null;

  @override
  double? get focusBorderWidth => null;

  @override
  double? get focusBorderRadius => 0;

  @override
  int? get focusAnimationDurationMs => null;

  @override
  void dispose() {}
}
