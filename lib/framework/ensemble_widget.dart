import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:flutter/cupertino.dart';

abstract class EnsembleWidget<C extends EnsembleController> extends StatefulWidget {
  const EnsembleWidget(this.controller, {super.key});
  final C controller;
}

abstract class EnsembleWidgetState<W extends EnsembleWidget> extends State<W> {
  void _update() {
    setState(() {

    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(covariant W oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_update);
    widget.controller.addListener(_update);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }
}

