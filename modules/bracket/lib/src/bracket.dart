// ignore_for_file: avoid_print

import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/model.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/layout/templated.dart';
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:flutter/material.dart';

class Bracket extends EnsembleWidget<BracketController> {
  static const type = 'Bracket';

  const Bracket._(super.controller);

  factory Bracket.build(dynamic controller) => Bracket._(
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

class BracketState extends EnsembleWidgetState<Bracket>
    with TemplatedWidgetState {
  List<RoundData> roundData = [];
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
      for (dynamic dataItem in dataList) {
        ScopeManager dataScope = myScope.createChildScope();
        dataScope.dataContext.addDataContextById(itemTemplate.name, dataItem);

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
          evaluateInitialValue: true, onDataChanged: (dataList) {
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
    );
  }
}

class BracketsView extends StatefulWidget {
  final List<RoundData> data;
  final BracketController controller;
  const BracketsView({
    super.key,
    required this.data,
    required this.controller,
  });

  @override
  State<BracketsView> createState() => _BracketsViewState();
}

class _BracketsViewState extends State<BracketsView> {
  late PageController _pageController;
  int _currentPageIndex = 0;
  List<GlobalKey> _tabKeys = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.75);
    _pageController.addListener(_updatePageIndex);
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
    return Column(
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
          child: BracketsPage(
            controller: widget.controller,
            pageController: _pageController,
            data: widget.data,
          ),
        ),
      ],
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
    _scrollControllers[index].animateTo(0.0,
        duration: const Duration(milliseconds: 600), curve: Curves.decelerate);
    _scrollControllers[index].animateTo(0.1,
        duration: const Duration(milliseconds: 10), curve: Curves.decelerate);

    setState(() {
      _prevColumnIndex = index;
    });
  }

  @override
  void dispose() {
    for (var controller in _scrollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<CustomScrollNotification>(
      onNotification: (CustomScrollNotification notification) {
        int currentPage = widget.pageController.page?.round() ?? 0;
        _scrollControllers[currentPage + 1].jumpTo(notification.scrollPosition);
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

              widget.roundData.localScope.dataContext
                  .addDataContextById(widget.roundData.matches.name, matchData);

              final cellWidget = widget.roundData.localScope
                  .buildWidgetFromDefinition(widget.roundData.matches.template);
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
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: cellWidget,
                  ),
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
