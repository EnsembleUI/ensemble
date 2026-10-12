import 'package:ensemble_test_runner/cli/cli_process_output.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retains observed ordering across child output streams', () {
    final transcript = CliProcessTranscript()
      ..add('stderr', 'startup lock wait')
      ..add('stdout', 'test started')
      ..add('stderr', 'worker interrupted');

    expect(
      transcript.text,
      '[stderr] startup lock wait\n'
      '[stdout] test started\n'
      '[stderr] worker interrupted\n',
    );
  });

  test('bounds transcript memory and marks an omitted prefix', () {
    final transcript = CliProcessTranscript(maxCharacters: 80, maxLines: 2)
      ..add('stdout', 'first')
      ..add('stderr', 'second')
      ..add('stdout', 'third');

    expect(
      transcript.text,
      '[earlier output omitted]\n[stderr] second\n[stdout] third\n',
    );
  });
}
