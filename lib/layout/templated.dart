
import 'package:flutter/cupertino.dart';

class Templated extends StatefulWidget {
  const Templated({
    Key? key,
    required this.localDataMap,
    required this.child
  }) : super(key: key);

  final Map<String, dynamic> localDataMap;
  final Widget child;

  @override
  TemplatedState createState() => TemplatedState();

}

class TemplatedState extends State<Templated> {

  @override
  Widget build(BuildContext context) {
    return Container(child: widget.child);
  }




}