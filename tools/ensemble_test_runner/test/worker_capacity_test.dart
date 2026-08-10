import 'package:ensemble_test_runner/src/worker_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

const _gibibyte = 1024 * 1024 * 1024;

void main() {
  test('uses one worker for a single test', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 1,
        logicalProcessorCount: 24,
        totalMemoryBytes: 64 * _gibibyte,
      ),
      1,
    );
  });

  test('selects four workers for a 10-core 16 GiB machine', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 10,
        totalMemoryBytes: 16 * _gibibyte,
      ),
      4,
    );
  });

  test('memory limits workers on a low-memory machine', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 16,
        totalMemoryBytes: 8 * _gibibyte,
      ),
      1,
    );
  });

  test('scales beyond the old five-worker ceiling', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 24,
        totalMemoryBytes: 64 * _gibibyte,
      ),
      11,
    );
  });

  test('never creates more workers than tests', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 3,
        logicalProcessorCount: 24,
        totalMemoryBytes: 64 * _gibibyte,
      ),
      3,
    );
  });

  test('falls back to the CPU budget when memory is unavailable', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 12,
      ),
      5,
    );
  });
}
