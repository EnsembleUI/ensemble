import 'package:flutter_test/flutter_test.dart';
import 'worker.dart';

void main() {
  final binding = LiveTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.onlyPumps;
  benchmarkWorkerMain();
}
