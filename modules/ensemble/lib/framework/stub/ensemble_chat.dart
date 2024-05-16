import 'package:ensemble/widget/stub_widgets.dart';

abstract class EnsembleChat {
  static const type = 'Chat';
}

class EnsembleChatStub extends StubWidget implements EnsembleChat {
  const EnsembleChatStub({super.key}) : super(moduleName: 'ensemble_chat');
}
