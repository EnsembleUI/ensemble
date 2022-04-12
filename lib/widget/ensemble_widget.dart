import 'package:ensemble/widget/widget_builder.dart' as ensemble;
import 'package:flutter/cupertino.dart';

/// to participate in Ensemble layout, extend your widget with this base Stateful widget
abstract class EnsembleStatefulWidget extends StatefulWidget {
  /// widget can be stretched inside Row/Column/Stack,
  /// this is applicable to all Ensemble widgets
  late final bool _expanded;
  bool get expanded => _expanded;


  EnsembleStatefulWidget({
    required ensemble.WidgetBuilder builder,
    Key? key
  }) : super(key: key) {
    _expanded = builder.expanded;
  }
}

/// If your Stateful widget wants to get/set its values from Ensemble layout,
/// extend it with this base class
abstract class UpdatableStatefulWidget extends EnsembleStatefulWidget with UpdatableWidget {
  UpdatableStatefulWidget({
    required ensemble.WidgetBuilder builder,
    Key? key
  }) : super(builder: builder, key: key);

}

/// expose methods for a StatefulWidget to get/set its values
mixin UpdatableWidget {
  final WidgetData _data = WidgetData();
  WidgetData get data => _data;

  dynamic getProperty(String key) {
    return getters()[key];
  }

  void setProperty(String key, dynamic value) {
    if (setters()[key] != null) {
      setters()[key]!(value);
      // notify state to reload
      _data.reload();
    }
  }

  // to be implemented by sub-class
  Map<String, Function> setters();
  Map<String, Function> getters();

}

class WidgetData extends ChangeNotifier {
  void reload() {
    notifyListeners();
  }
}

/// extend your Widget State with this for Stateful widget that needs to
/// get/set its value. Use in conjunction with UpdatableStatefulWidget.
abstract class EnsembleWidgetState<S extends UpdatableStatefulWidget> extends State<S> {
  void changeState() {
    setState(() {

    });
  }

  @override
  void initState() {
    super.initState();
    widget.data.addListener(changeState);
  }
  @override
  void didUpdateWidget(covariant S oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.data.removeListener(changeState);
    widget.data.addListener(changeState);
  }
  @override
  void dispose() {
    super.dispose();
    widget.data.removeListener(changeState);
  }
}