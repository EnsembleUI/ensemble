import 'package:flutter/material.dart';

/// a wrapper around Screen and make it modal
class ModalScreen extends StatelessWidget {
  const ModalScreen({Key? key, required this.screenWidget}) : super(key: key);

  final Widget screenWidget;

  @override
  Widget build(BuildContext context) {
    double topMargin = 60;
    double bottomMargin = 0;
    double sideMargin = 0;

    double width = MediaQuery.of(context).size.width;
    if (width < 500) {
      sideMargin = 0;
    } else if (width < 900) {
      sideMargin = 30;
    } else {
      sideMargin = 50;
    }

    double height = MediaQuery.of(context).size.height;
    if (height < 900) {
      topMargin = 60;
      bottomMargin = 0;
    } else {
      topMargin = bottomMargin = 60;
    }

    /// repurpose dialog screen with frosted background. ModalScreen for now is just simply full screen
    /*
    return Container(
      margin: EdgeInsets.fromLTRB(sideMargin, topMargin, sideMargin, bottomMargin),
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
    );*/

    return screenWidget;
  }
}
