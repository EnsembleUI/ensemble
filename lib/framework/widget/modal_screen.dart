import 'package:flutter/material.dart';

/// a wrapper around Screen and make it modal
class ModalScreen extends StatelessWidget {
  const ModalScreen({
    Key? key,
    required this.screenWidget}) : super(key: key);

  final Widget screenWidget;


  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(50),
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(5)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.white38,
            blurRadius: 5,
            offset: Offset(0, 0),
          )
        ]
      ),
      child: screenWidget
    );
  }


}