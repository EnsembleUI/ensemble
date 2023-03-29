import 'dart:async';

import 'package:ensemble/framework/widget/widget.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

class DiagramController extends WidgetController {
  List<ImageNode> images = [];
  ImageNode createImageNode(String name, String imagePath, Size size,
      {Offset? position, Subtree? subtree}) {
    ImageNode node = ImageNode(name, imagePath, size);
    node.position = position;
    node.subtree = subtree;
    images.add(node);
    return node;
  }

  Future<void> init() async {
    if (_nodes.isEmpty) {
      Map<String, Node> m = {};
      //Rectangle node = Rectangle('node0', const Size(60,60),const Offset(10,0), Colors.green);
      ImageNode node = createImageNode(
          'node0', 'assets/images/img_placeholder.png', const Size(170, 107),
          position: const Offset(10, 0));
      node.subtree = Subtree([
        CompositeNode(
            'compnode1',
            [
              createImageNode('img1', 'assets/images/img_placeholder.png',
                  const Size(50, 50)),
              TextNode('mytext1', '2.4 GHz'),
            ],
            gap: 0,
            layout: 'horizontal'),
        CompositeNode(
            'compnode2',
            [
              createImageNode('img1', 'assets/images/img_placeholder.png',
                  const Size(50, 50)),
              TextNode('mytext2', '+5 more WiFi devices'),
            ],
            gap: 0,
            layout: 'horizontal'),
      ], ConnectionPoint(node, 'right', 'center', 0), distanceFromParent: 150);
      m['node0'] = node;

      m['node1'] = createImageNode(
          'node1', 'assets/images/img_placeholder.png', const Size(170, 107),
          position: const Offset(10, 127));
      m['node2'] = createImageNode(
          'node2', 'assets/images/img_placeholder.png', const Size(15, 23),
          position: const Offset(500, 380));
      m['node3'] = createImageNode(
          'node3', 'assets/images/img_placeholder.png', const Size(15, 23),
          position: const Offset(500, 423));
      m['node4'] = createImageNode(
          'node4', 'assets/images/img_placeholder.png', const Size(15, 23),
          position: const Offset(500, 476));

      Node node5 = createImageNode(
        'node5',
        'assets/images/img_placeholder.png',
        const Size(170, 107),
        position: const Offset(500, 120),
      );
      node5.subtree = Subtree([
        CompositeNode(
            'compnode1',
            [
              createImageNode('img1', 'assets/images/img_placeholder.png',
                  const Size(50, 50)),
              TextNode('mytext1', '5 GHz'),
            ],
            gap: 0,
            layout: 'horizontal'),
        CompositeNode(
            'compnode2',
            [
              createImageNode('img1', 'assets/images/img_placeholder.png',
                  const Size(50, 50)),
              TextNode('mytext2', '+3 more WiFi devices'),
            ],
            gap: 0,
            layout: 'horizontal'),
      ], ConnectionPoint(node5, 'right', 'center', 0), distanceFromParent: 250);
      m['node5'] = node5;
      Node node6 = createImageNode(
          'node5', 'assets/images/img_placeholder.png', const Size(170, 107),
          position: const Offset(500, 240));
      node6.subtree = Subtree([
        CompositeNode(
            'compnode1',
            [
              createImageNode('img1', 'assets/images/img_placeholder.png',
                  const Size(50, 50)),
              TextNode('mytext1', '2.4 GHz'),
            ],
            gap: 0,
            layout: 'horizontal'),
        CompositeNode(
            'compnode2',
            [
              createImageNode('img1', 'assets/images/img_placeholder.png',
                  const Size(50, 50)),
              TextNode('mytext2', '+2 more WiFi devices'),
            ],
            gap: 0,
            layout: 'horizontal'),
      ], ConnectionPoint(node6, 'right', 'center', 0), distanceFromParent: 250);
      m['node6'] = node6;

      _nodes = m;
      for (ImageNode img in images) {
        await img.init();
      }
    }
  }

  Map<String, Node> _nodes = {};
  Map<String, Node> get nodes {
    if (_nodes.isEmpty) {
      init();
    }
    return _nodes;
  }

  List<Connection> _connections = [];
  List<Connection> get connections {
    if (_connections.isEmpty) {
      _connections.add(Connection(
          ConnectionPoint(nodes['node1']!, 'bottom', 'center', -15),
          ConnectionPoint(nodes['node4']!, 'left', 'center', 0),
          Colors.orange,
          strokeWidth: 2,
          style: 'kinked'));
      _connections.add(Connection(
          ConnectionPoint(nodes['node1']!, 'bottom', 'center', 0),
          ConnectionPoint(nodes['node3']!, 'left', 'center', 0),
          Colors.orange,
          strokeWidth: 2,
          style: 'kinked'));
      _connections.add(Connection(
          ConnectionPoint(nodes['node1']!, 'bottom', 'center', 15),
          ConnectionPoint(nodes['node2']!, 'left', 'center', 0),
          Colors.orange,
          strokeWidth: 2,
          style: 'kinked'));
      _connections.add(Connection(
          ConnectionPoint(nodes['node0']!, 'right', 'end', -30),
          ConnectionPoint(nodes['node5']!, 'left', 'center', 0),
          Colors.grey,
          strokeWidth: 2,
          style: 'kinked'));
      _connections.add(Connection(
          ConnectionPoint(nodes['node0']!, 'right', 'end', -15),
          ConnectionPoint(nodes['node6']!, 'left', 'center', 0),
          Colors.grey,
          strokeWidth: 2,
          style: 'kinked'));
    }
    return _connections;
  }
}

class Diagram extends StatefulWidget
    with Invokable, HasController<DiagramController, DiagramState> {
  static const type = 'Diagram';
  Diagram({Key? key}) : super(key: key);

  final DiagramController _controller = DiagramController();
  @override
  DiagramController get controller => _controller;

  @override
  State<StatefulWidget> createState() => DiagramState();

  @override
  Map<String, Function> getters() {
    // TODO: implement getters
    throw UnimplementedError();
  }

  @override
  Map<String, Function> methods() {
    // TODO: implement methods
    throw UnimplementedError();
  }

  @override
  Map<String, Function> setters() {
    // TODO: implement setters
    throw UnimplementedError();
  }
}

class Subtree {
  double distanceFromParent = 30;
  double branchLength = 6;
  List<Node>? children;
  Color color = Colors.black;
  double strokeWidth = 2;
  double gapBetweenChildren = 20;
  ConnectionPoint startPoint;
  Subtree(this.children, this.startPoint,
      {this.distanceFromParent = 30,
      this.branchLength = 6,
      this.color = Colors.black,
      this.strokeWidth = 2,
      this.gapBetweenChildren = 20});
}

abstract class Node {
  String name;
  Subtree? subtree;
  Offset? position;
  Size? size;
  Node(this.name, {this.size, this.position, this.subtree});
  draw(Canvas canvas);
}

class CompositeNode extends Node {
  List<Node> children;
  String layout;
  double gap;
  CompositeNode(String name, this.children,
      {Offset? position,
      this.layout = 'vertical',
      this.gap = 5,
      Subtree? subtree})
      : super(name, position: position, subtree: subtree);

  @override
  draw(Canvas canvas) {
    if (position == null) {
      throw Exception(
          'Position is null when trying to to draw compositenode with name=$name');
    }
    Offset currPosition = position!;
    for (Node child in children) {
      child.position = currPosition;
      child.draw(canvas);
      if (layout == 'vertical') {
        currPosition =
            Offset(currPosition.dx, currPosition.dy + child.size!.height + gap);
      } else {
        currPosition =
            Offset(currPosition.dx + child.size!.width + gap, currPosition.dy);
      }
    }
  }
}

class TextNode extends Node {
  String text;
  Color color;
  double fontSize;

  TextNode(String name, this.text,
      {position, this.color = Colors.black, this.fontSize = 12})
      : super(name, position: position);
  @override
  void draw(Canvas canvas) {
    if (position == null) {
      throw Exception("Position must be specified");
    }
    TextSpan span = TextSpan(style: TextStyle(color: color), text: text);
    TextPainter tp = TextPainter(
        text: span,
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(position!.dx, position!.dy - tp.size.height / 2));
    size = tp.size;
  }
}

class Rectangle extends Node {
  Color color;
  PaintingStyle style;
  Rect? rect;
  Rectangle(String name, Size size, Offset position, this.color,
      {this.style = PaintingStyle.fill})
      : super(name, position: position, size: size);
  Rectangle.from(String name, Offset position, Size size, Color color,
      [style = PaintingStyle.fill])
      : this(name, size, position, color, style: style);
  @override
  void draw(Canvas canvas) {
    final paint = Paint()
      ..style = style
      ..color = color;
    rect = Rect.fromLTWH(position!.dx, position!.dy, size!.width, size!.height);
    canvas.drawRect(rect!, paint);
  }
}

class ImageNode extends Node {
  String imgPath;
  ui.Image? image;
  ImageNode(String name, this.imgPath, size, {position, subtree})
      : super(name, size: size, position: position, subtree: subtree);

  init() async {
    if (image != null) {
      return;
    }
    final ByteData data = await rootBundle.load(imgPath);
    image = await decodeImageFromList(data.buffer.asUint8List());

    // final Completer<ui.Image> completer = Completer();
    // ui.decodeImageFromList(Uint8List.view(data.buffer), (ui.Image img) {
    //   canvas.drawImage(img, position!, Paint());
    //   return completer.complete(img);
    // });
    // return completer.future;
  }

  @override
  draw(Canvas canvas) {
    if (position == null) {
      throw Exception(
          'position of the ImageNode is null. Make sure node has position');
    }
    if (image == null) {
      return;
      //throw Exception('Image of the ImageNode is null. Image has not yet been fetched');
    }

    canvas.drawImage(image!, position!, Paint());
  }
}

class ConnectionPoint {
  Node node;
  String side, offsetFrom;
  double offset;
  ConnectionPoint(this.node, this.side, this.offsetFrom, this.offset);
}

class Connection {
  ConnectionPoint from, to;
  String style;
  Color color;
  double strokeWidth;
  Connection(this.from, this.to, this.color,
      {this.strokeWidth = 2, this.style = 'straight'});
}

class DiagramPainter extends CustomPainter {
  DiagramController controller;
  DiagramPainter(this.controller);
  Offset getConnectionPointCoordinates(ConnectionPoint point) {
    if (point.node.size == null) {
      throw Exception(
          'size of the node is null for the connection point. Make sure node is drawn first and has size');
    }
    if (point.node.position == null) {
      throw Exception(
          'position of the node is null for the connection point. Make sure node is drawn first and has position');
    }
    double x = 0;
    double y = 0;
    if (point.side == 'bottom' || point.side == 'top') {
      if (point.side == 'top') {
        y = point.node.position!.dy;
      } else {
        y = point.node.position!.dy + point.node.size!.height;
      }
      x = point.node.position!.dx;
      if (point.offsetFrom == 'start') {
        x += point.offset;
      } else if (point.offsetFrom == 'center') {
        x += point.node.size!.width / 2 + point.offset;
      } else {
        x += point.node.size!.width + point.offset;
      }
    } else if (point.side == 'left' || point.side == 'right') {
      if (point.side == 'left') {
        x = point.node.position!.dx;
      } else {
        x = point.node.position!.dx + point.node.size!.width;
      }
      y = point.node.position!.dy;
      if (point.offsetFrom == 'start') {
        y += point.offset;
      } else if (point.offsetFrom == 'center') {
        y += point.node.size!.height / 2 + point.offset;
      } else {
        y += point.node.size!.height + point.offset;
      }
    }
    return Offset(x, y);
  }

  void paintConnection(Canvas canvas, Connection connection) {
    Offset from = getConnectionPointCoordinates(connection.from);
    Offset to = getConnectionPointCoordinates(connection.to);
    final paint = Paint()
      ..color = connection.color
      ..strokeWidth = connection.strokeWidth;
    if (connection.style == 'kinked') {
      double startx = from.dx;
      if (connection.from.side == 'right') {
        startx += ((to.dx - from.dx) / 10).round();
        canvas.drawLine(from, Offset(startx, from.dy), paint);
      }
      canvas.drawLine(Offset(startx, from.dy), Offset(startx, to.dy), paint);
      canvas.drawLine(Offset(startx, to.dy), to, paint);
    } else {
      canvas.drawLine(from, to, paint);
    }
  }

  void paintChildren(Canvas canvas, Node node) {
    //makes the forked children tree
    if (node.subtree == null || node.subtree!.children == null) {
      return;
    }
    Offset point = getConnectionPointCoordinates(node.subtree!.startPoint);
    final paint = Paint()
      ..color = node.subtree!.color
      ..strokeWidth = node.subtree!.strokeWidth;
    if (node.subtree!.startPoint.side == 'right') {
      double offsetX = point.dx + node.subtree!.distanceFromParent;
      canvas.drawLine(point, Offset(offsetX, point.dy), paint);
      int n = node.subtree!.children!.length;
      double startY =
          point.dy - ((n - 1) * node.subtree!.gapBetweenChildren / 2);
      canvas.drawLine(
          Offset(offsetX, startY),
          Offset(offsetX,
              point.dy + ((n - 1) * node.subtree!.gapBetweenChildren / 2)),
          paint);

      for (int i = 0; i < node.subtree!.children!.length; i++) {
        Offset endPoint = Offset(offsetX + node.subtree!.branchLength,
            startY + i * node.subtree!.gapBetweenChildren);
        canvas.drawLine(
            Offset(offsetX, startY + i * node.subtree!.gapBetweenChildren),
            endPoint,
            paint);
        Node child = node.subtree!.children![i];
        child.position = Offset(endPoint.dx + 2, endPoint.dy);
        child.draw(canvas);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    Map<String, Node> m = controller.nodes;
    for (var key in m.keys) {
      Node node = m[key]!;
      node.draw(canvas);
      paintChildren(canvas, node);
    }
    for (Connection conn in controller.connections) {
      paintConnection(canvas, conn);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}

class DiagramState extends WidgetState<Diagram> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget buildWidget(BuildContext context) {
    return FutureBuilder(
        future: widget.controller.init(),
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CustomPaint(
              painter: DiagramPainter(widget.controller),
            );
          } else if (snapshot.hasError) {
            return const Text("Error...");
          }
          return const Text("Loading...");
        });
  }
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Welcome to Flutter',
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Diagrammer'),
            ),
            body: Padding(
              child: Column(children: [Diagram()]),
              padding: const EdgeInsets.all(16.0),
            )));
  }
}
