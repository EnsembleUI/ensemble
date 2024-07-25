import 'package:ensemble/widget/stub_widgets.dart';

abstract class EnsembleBracket {
  static const type = 'Bracket';
}

class EnsembleBracketStub extends StubWidget implements EnsembleBracket {
  const EnsembleBracketStub({super.key})
      : super(moduleName: 'ensemble_bracket');
}
