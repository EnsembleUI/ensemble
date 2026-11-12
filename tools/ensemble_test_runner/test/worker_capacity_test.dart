import 'package:ensemble_test_runner/src/worker_capacity.dart';
import 'package:flutter_test/flutter_test.dart';

const _gibibyte = 1024 * 1024 * 1024;

void main() {
  test('uses one worker for a single test', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 1,
        logicalProcessorCount: 24,
        availableMemoryBytes: 64 * _gibibyte,
      ),
      1,
    );
  });

  test('uses three workers when memory covers three worker budgets', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 10,
        availableMemoryBytes: 16 * _gibibyte,
      ),
      3,
    );
  });

  test('memory limits workers on a low-memory machine', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 16,
        availableMemoryBytes: 8 * _gibibyte,
      ),
      1,
    );
  });

  test('caps automatic concurrency to protect the host', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 24,
        availableMemoryBytes: 64 * _gibibyte,
      ),
      4,
    );
  });

  test('never creates more workers than tests', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 3,
        logicalProcessorCount: 24,
        availableMemoryBytes: 64 * _gibibyte,
      ),
      3,
    );
  });

  test('falls back to one worker when memory is unavailable', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 12,
      ),
      1,
    );
  });

  test('keeps one worker when memory covers less than two worker budgets', () {
    expect(
      calculateAutomaticWorkerCount(
        testCount: 60,
        logicalProcessorCount: 24,
        availableMemoryBytes: 10 * _gibibyte,
      ),
      1,
    );
  });
}
