
import 'package:flutter/cupertino.dart';

class Templated extends StatefulWidget {
  Templated({
    Key? key,
    required this.localDataMap,
    required this.child
  }) : super(key: key);

  final Map<String, dynamic> localDataMap;
  final Widget child;
  final TemplatedState currentState = TemplatedState();


  @override
  TemplatedState createState() => currentState;

  TemplatedState getState() {
    return currentState;
  }


}

class TemplatedState extends State<Templated> {

  @override
  Widget build(BuildContext context) {
    return Container(child: widget.child);
  }




}