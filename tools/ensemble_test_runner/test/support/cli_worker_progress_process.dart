import 'package:ensemble_test_runner/cli/cli_worker_progress_output.dart';

void main(List<String> arguments) {
  final path = arguments.single;
  CliWorkerProgressOutput.drainFiles([path], {path: 0});
}
