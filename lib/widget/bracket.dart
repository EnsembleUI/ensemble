import 'package:ensemble/framework/ensemble_widget.dart';
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
  final String title;
  final ItemTemplate matches;

  RoundTemplate({
    required String data,
    required String name,
    dynamic template,
    required this.title,
    required this.matches,
  }) : super(data, name, template);
}

class RoundData {
  final String title;
  final ItemTemplate matches;
  final ScopeManager localScope;

  RoundData({
    required this.title,
    required this.matches,
    required this.localScope,
  });
}

class BracketController extends EnsembleBoxController {
  BracketController();

  RoundTemplate? roundTemplate;

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
      'items': (data) {
        roundTemplate = RoundTemplate(
          data: data['data'],
          name: data['name'],
          title: data['title'],
          matches: ItemTemplate(
            data['item-template']['data'],
            data['item-template']['name'],
            data['item-template']['template'],
          ),
        );
      }
    });
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
              fallback: '',
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
    return BracketsView(data: roundData);
  }
}

class BracketsView extends StatefulWidget {
  final Color bracketBackgroundColor;
  final Color bracketColor;
  final Color textColor;
  final List<RoundData> data;

  const BracketsView({
    Key? key,
    this.bracketBackgroundColor = Colors.white,
    this.bracketColor = Colors.black,
    this.textColor = Colors.black,
    required this.data,
  }) : super(key: key);

  @override
  _BracketsViewState createState() => _BracketsViewState();
}

class _BracketsViewState extends State<BracketsView> {
  late PageController _pageController;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.75);
    _pageController.addListener(_updatePageIndex);
  }

  void _updatePageIndex() {
    int newPage = _pageController.page!.round();
    if (newPage != _currentPageIndex) {
      setState(() {
        _currentPageIndex = newPage;
      });
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
    return Container(
      color: widget.bracketBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(widget.data.length, (index) {
                bool isSelected = index == _currentPageIndex;
                String? title = widget.data.elementAt(index).title;
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ElevatedButton(
                    onPressed: () => _animateToPage(index),
                    style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.all<Color>(
                          isSelected ? Colors.blue : widget.bracketColor),
                      foregroundColor:
                          MaterialStateProperty.all<Color>(Colors.white),
                    ),
                    child: Text(title),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: BracketsPage(
              controller: _pageController,
              data: widget.data,
              bracketColor: widget.bracketColor,
              textColor: widget.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class BracketsPage extends StatefulWidget {
  final List<RoundData> data;
  final Color bracketColor;
  final Color textColor;
  final PageController controller;

  const BracketsPage({
    Key? key,
    required this.data,
    required this.bracketColor,
    required this.textColor,
    required this.controller,
  }) : super(key: key);

  @override
  _BracketsPageState createState() => _BracketsPageState();
}

class _BracketsPageState extends State<BracketsPage> {
  int _prevColumnIndex = 0;

  void _onPageChanged(int index) {
    setState(() {
      _prevColumnIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      padEnds: false,
      controller: widget.controller,
      itemCount: widget.data.length,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, columnIndex) {
        final columnData = widget.data[columnIndex];
        return BracketsColumnPage(
          columnData: columnData,
          bracketColor: widget.bracketColor,
          textColor: widget.textColor,
          columnIndex: columnIndex,
          prevColumnIndex: _prevColumnIndex,
          totalColumns: widget.data.length,
        );
      },
    );
  }
}

class BracketsColumnPage extends StatefulWidget {
  final RoundData columnData;
  final Color bracketColor;
  final Color textColor;
  final int columnIndex;
  final int prevColumnIndex;
  final int totalColumns;
  const BracketsColumnPage({
    Key? key,
    required this.columnData,
    required this.bracketColor,
    required this.textColor,
    required this.columnIndex,
    required this.prevColumnIndex,
    required this.totalColumns,
  }) : super(key: key);

  @override
  State<BracketsColumnPage> createState() => _BracketsColumnPageState();
}

class _BracketsColumnPageState extends State<BracketsColumnPage> {
  final double matchCardHeight = 100;
  List computedMatches = [];

  @override
  void initState() {
    computedMatches = widget.columnData.localScope.dataContext
        .eval(widget.columnData.matches.data);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ...computedMatches.asMap().entries.map((entry) {
          final matchIndex = entry.key;
          final matchData = entry.value;

          double topOffset = matchIndex * matchCardHeight;
          if (widget.prevColumnIndex < widget.columnIndex) {
            topOffset = topOffset + (matchCardHeight / 2);
            topOffset = topOffset + (matchCardHeight * matchIndex);
          }

          widget.columnData.localScope.dataContext
              .addDataContextById(widget.columnData.matches.name, matchData);

          final cellWidget = widget.columnData.localScope
              .buildWidgetFromDefinition(widget.columnData.matches.template);
          return AnimatedPositioned(
            height: matchCardHeight,
            width: MediaQuery.of(context).size.width * 0.60,
            duration: const Duration(milliseconds: 300),
            top: topOffset,
            child: CustomPaint(
              painter: BracketPainter(
                isTopBracket: widget.columnIndex + 1 == widget.totalColumns
                    ? null
                    : !(matchIndex % 2 == 0),
                showLeftBorder: widget.prevColumnIndex < widget.columnIndex,
              ),
              child: cellWidget,
            ),
          );
        }).toList(),
      ],
    );
  }
}

class BracketPainter extends CustomPainter {
  final bool? isTopBracket;
  final bool showLeftBorder;

  BracketPainter({this.isTopBracket, required this.showLeftBorder});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);

    // Horizontal line

    // Vertical line
    if (isTopBracket != null) {
      final startPoint = Offset(size.width, size.height / 2);
      final endPoint = Offset(size.width + 25, size.height / 2);
      canvas.drawLine(startPoint, endPoint, paint);

      const double verticalLength = 40;
      final verticalStartPoint = endPoint;
      final verticalEndPoint = isTopBracket!
          ? Offset(endPoint.dx, endPoint.dy - verticalLength)
          : Offset(endPoint.dx, endPoint.dy + verticalLength);
      canvas.drawLine(verticalStartPoint, verticalEndPoint, paint);
    }
    if (showLeftBorder) {
      final leftStartPoint = Offset(0, size.height / 2);
      final leftEndPoint = Offset(-25, size.height / 2);
      canvas.drawLine(leftStartPoint, leftEndPoint, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
