import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:flutter/cupertino.dart';

abstract class EnsembleStatefulWidget extends StatefulWidget {
  late final bool _expanded;
  bool get expanded => _expanded;


  EnsembleStatefulWidget({
    required ensemble.WidgetBuilder builder,
    Key? key
  }) : super(key: key) {
    _expanded = builder.expanded;
  }


}