import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/form_time.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablelist.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablemap.dart';
import 'package:flutter/material.dart';
import 'package:yaml/yaml.dart';

class DailySchedulerController extends WidgetController {
  late String dayLabel;
  int startSeconds = 0;
  int intervalInMinutes = 30;
  final List<Node> _nodes = [];
  double gapX = 2;
  Color selectedColor = Colors.green;
  Color unselectedColor = Colors.grey;
  double slotWidth = 16;
  double slotHeight = 16;
  List<TimeRange> selectedRanges = [];
  bool isSelected(TimeRange slotTime) {
    for ( TimeRange range in selectedRanges ) {
      if ( slotTime.startTime >= range.startTime && slotTime.endTime <= range.endTime ) {
        return true;
      }
    }
    return false;
  }
  List<TimeRange> getSelectedRanges() {
    List<TimeRange> ranges = [];
    TimeRange? currentRange;
    for ( Node node in nodes ) {
      if ( node.selected ) {
        if ( currentRange == null ) {
          currentRange = TimeRange(node.range.startTime, node.range.endTime);
          ranges.add(currentRange);
        } else {
          currentRange.endTime = node.range.endTime;
        }
      } else {
        currentRange = null;
      }
    }
    return ranges;
  }
  void refresh() {
    bool shouldRefresh = false;
    int numberOfBoxes = (24 * 60 /intervalInMinutes).round();
    for ( int i=0;i<numberOfBoxes;i++ ) {
      TimeRange slotTime = TimeRange(startSeconds + (i * intervalInMinutes * 60),
          startSeconds + ((i+1) * intervalInMinutes * 60));
      bool selected = isSelected(slotTime);
      if ( nodes[i].selected != selected ) {
        nodes[i].toggle();
        shouldRefresh = true;
      }
    }
    if ( shouldRefresh ) {
      notifyListeners();
    }
  }
  List<Node> get nodes {
    if ( _nodes.isNotEmpty ) {
      return _nodes;
    }
    Offset initialOffset = const Offset(0,0);
    Size size = Size(slotWidth,slotHeight);
    final unselectedPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = selectedColor;
    final selectedPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = unselectedColor;
    int numberOfBoxes = (24 * 60 /intervalInMinutes).round();
    for ( int i=0;i<numberOfBoxes;i++ ) {
      String startTime = '${(i/(60/intervalInMinutes)).floor()}:${(i==0 || i*intervalInMinutes==60)?'00': intervalInMinutes}';
      String endTime = '${((i+1)/(60/intervalInMinutes)).floor()}:${((i+1)*intervalInMinutes==60)?'00': intervalInMinutes}';
      TimeRange slotTime = TimeRange(startSeconds + (i * intervalInMinutes * 60),
          startSeconds + ((i+1) * intervalInMinutes * 60));
      _nodes.add(
          Node(Rect.fromLTWH(initialOffset.dx + (i * size.width) + (i * gapX), initialOffset.dy, size.width, size.height),
              slotTime,
              startTime,
              endTime,
              isSelected(slotTime), unselectedPaint,selectedPaint
          )
      );
    }
    return _nodes;
  }
  Node? getNodeUnderPoint(Offset point) {
    for ( Node node in nodes ) {
      if ( node.contains(point) ) {
        return node;
      }
    }
    return null;
  }
  bool isPointerDown = false;
  int selectedNodeIndex = -1;

  void onPointerDown(PointerEvent event) {
    isPointerDown = true;
    //print('OnPointerDown: (${event.localPosition.dx},${event.localPosition.dy})');
    Node? node = getNodeUnderPoint(event.localPosition);
    if ( node != null ) {
      int index = nodes.indexOf(node);
      if ( index != selectedNodeIndex ) {
        selectedNodeIndex = index;
        node.toggle();
        print('${node.selected?'selected':'UNselected'}: $dayLabel - ${node.range.startTime} to ${node.range.endTime}');
        notifyListeners();
      }
    }
  }
  void onPointerMove(PointerEvent event) {
    //print('onPointerMove: (${event.localPosition.dx},${event.localPosition.dy})');
    if ( !isPointerDown ) {
      return;
    }
    //print('onPointerMove: (${event.localPosition.dx},${event.localPosition.dy})');
    Node? node = getNodeUnderPoint(event.localPosition);
    if ( node != null ) {
      int index = nodes.indexOf(node);
      if ( index != selectedNodeIndex ) {
        selectedNodeIndex = index;
        node.toggle();
        print('${node.selected?'selected':'UNselected'}: $dayLabel - ${node.range.startTime} to ${node.range.endTime}');
        notifyListeners();
      }
    }
  }
  void onPointerUp(PointerEvent event) {
    isPointerDown = false;
    selectedNodeIndex = -1;
    //print('onPointerUp: (${event.localPosition.dx},${event.localPosition.dy})');
  }
}

class DailyScheduler extends StatefulWidget with Invokable, HasController<DailySchedulerController,DailySchedulerState> {
  static const String type = 'DailyScheduler';
  DailyScheduler(this._controller,{super.key});

  final DailySchedulerController _controller;
  @override
  DailySchedulerController get controller => _controller;

  @override
  State<StatefulWidget> createState() => DailySchedulerState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
  
}
class DailySchedulerState extends WidgetState<DailyScheduler> {
  @override
  Widget buildWidget(BuildContext context) {
    return Listener(
        onPointerDown: widget.controller.onPointerDown,
        onPointerMove: widget.controller.onPointerMove,
        onPointerUp: widget.controller.onPointerUp,
        child: SizedBox(
            width: widget.controller.slotWidth * 48 + widget.controller.gapX * 47,
            height: widget.controller.slotHeight,
            child: CustomPaint (
              painter: SchedulerPainter(widget.controller.nodes,widget.controller),
            )
        )
    );
  }
}
class WeeklySchedulerController extends WidgetController {
  EdgeInsets padding = const EdgeInsets.fromLTRB(0, 0, 0, 2.0);
  List<String> dayLabels = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
  bool displayDayLabels = true;
  double gapX = 2;
  Color selectedColor = Colors.green;
  Color unselectedColor = Colors.grey;
  double slotWidth = 16;
  double slotHeight = 16;
  int slotInMinutes = 30;
  final List<DailySchedulerController> _dailyControllers = [];
  List<DailySchedulerController> get dailyControllers {
      return _dailyControllers;
  }
  void refresh() {
    for ( DailySchedulerController controller in dailyControllers ) {
      controller.refresh();
    }
  }
  void initControllers() {
    for (int i = 0; i < dayLabels.length; i++) {
      DailySchedulerController controller = DailySchedulerController();
      controller.dayLabel = dayLabels[i];
      controller.selectedColor = selectedColor;
      controller.unselectedColor = unselectedColor;
      controller.gapX = gapX;
      controller.startSeconds = i * 24 * 60 * 60;
      controller.slotWidth = slotWidth;
      controller.slotHeight = slotHeight;
      controller.intervalInMinutes = slotInMinutes;
      controller.selectedRanges = selectedRanges;
      _dailyControllers.add(controller);
    }
  }
  List<TimeRange> selectedRanges = [];
  List<Widget> getDailySchedulers() {
    List<Widget> schedulers = [];
    if ( _dailyControllers.isEmpty ) {
      initControllers();
    }
    for ( int i=0;i<dayLabels.length;i++ ) {
      DailyScheduler scheduler = DailyScheduler(dailyControllers[i]);
      if ( i < dayLabels.length -1 ) {
        schedulers.add(Padding(padding: padding, child: scheduler));
      } else {
        schedulers.add(scheduler);
      }
    }
    return schedulers;
  }
  List<TimeRange> getSelectedRanges() {
    List<TimeRange> ranges = [];
    for ( DailySchedulerController dailySchedulerController in _dailyControllers ) {
      ranges.addAll(dailySchedulerController.getSelectedRanges());
    }
    return ranges;
  }
}
class WeeklyScheduler extends StatefulWidget with Invokable,HasController<WeeklySchedulerController,WeeklySchedulerState> {
  static const String type = 'WeeklyScheduler';
  final WeeklySchedulerController _controller = WeeklySchedulerController();
  @override
  WeeklySchedulerController get controller => _controller;

  @override
  State<StatefulWidget> createState() => WeeklySchedulerState();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'getSelectedRanges': () {
        return controller.getSelectedRanges();
      },
      'addSelectedRange': (num startTime, num endTime) {
        controller.selectedRanges.add(TimeRange(startTime.toInt(), endTime.toInt()));
      },
      'refresh': () {
        controller.refresh();
      }

    };
  }
  static List<String> getDayLabels(List<dynamic> value) {
    if (value is YamlList) {
      List<String> results = [];
      for (var item in value) {
        results.add(item.toString());
      }
      return results;
    } else if ( value is InvokableList ) {
      return (value as InvokableList).list as List<String>;
    }
    return value as List<String>;
  }
  @override
  Map<String, Function> setters() {
    return {
      'dayLabels': (List<dynamic> dayLabels) => controller.dayLabels = getDayLabels(dayLabels),
      'paddingBetweenDays': (dynamic padding) => controller.padding = EdgeInsets.fromLTRB(0, 0, 0, Utils.getDouble(padding,fallback: 2.0)),
      'slotWidth': (dynamic width) => controller.slotWidth = Utils.getDouble(width, fallback: controller.slotWidth),
      'slotHeight': (dynamic height) => controller.slotHeight = Utils.getDouble(height, fallback: controller.slotHeight),
      'gapBetweenSlots': (dynamic gap) => controller.gapX = Utils.getDouble(gap,fallback:controller.gapX),
      'selectedSlotColor': (dynamic color) => controller.selectedColor = Utils.getColor(color) ?? controller.selectedColor,
      'unselectedSlotColor': (dynamic color) => controller.unselectedColor = Utils.getColor(color) ?? controller.unselectedColor,
      'slotInMinutes': (dynamic value) => controller.slotInMinutes = Utils.getInt(value, fallback: 30),
      'displayDayLabels': (dynamic value) => controller.displayDayLabels = Utils.getBool(value, fallback: controller.displayDayLabels),
    };
  }

}
class WeeklySchedulerState extends WidgetState<WeeklyScheduler> {
  void refresh() {
    setState(() {

    });
  }
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(refresh);
  }
  @override
  void dispose() {
    widget.controller.removeListener(refresh);
    super.dispose();
  }
  @override
  Widget buildWidget(BuildContext context) {
    return Column(
      children: widget.controller.getDailySchedulers(),
    );
  }

}
class TimeRange extends InvokableMap {
  TimeRange(int startTime,int endTime): super({'startTime':startTime,'endTime':endTime});
  set startTime(s) => map['startTime'] = s;
  get startTime => map['startTime'];
  set endTime(s) => map['endTime'] = s;
  get endTime => map['endTime'];
}
class Node {
  String startTime;
  String endTime;
  TimeRange range;
  Rect rect;
  Paint selectedPaint, unselectedPaint;
  bool selected;
  bool shouldRepaint = false;
  Paint get paint => (selected)?selectedPaint:unselectedPaint;
  Node(this.rect,
      this.range,
      this.startTime,this.endTime,
      this.selected,
      this.unselectedPaint,this.selectedPaint);
  bool contains(Offset point) {
    return point.dx >= rect.left && point.dx <= rect.right
        && point.dy >= rect.top && point.dy <= rect.bottom;
  }
  bool toggle() {
    selected = !selected;
    shouldRepaint = true;
    return selected;
  }
}
class SchedulerPainter extends CustomPainter {
  List<Node> nodes;
  SchedulerPainter(this.nodes,Listenable? repaint): super(repaint: repaint);
  @override
  void paint(Canvas canvas, Size size) {
    for ( Node node in nodes ) {
      canvas.drawRect(node.rect, node.paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    bool repaint = false;
    for ( Node node in nodes ) {
      if ( node.shouldRepaint ) {
        repaint = true;
      }
    }
    for ( Node node in nodes ) {
      node.shouldRepaint = false;
    }
    return repaint;
  }
}