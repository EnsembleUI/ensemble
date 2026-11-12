// Dart 3.8 reports deprecated_member_use at RegExp construction sites even though
// the deprecation is specifically about implementing RegExp. Keep construction compatible
// with this SDK without suppressing diagnostics in unrelated files.
// ignore_for_file: deprecated_member_use
import 'dart:io';

import 'package:ensemble_test_runner/src/benchmark_measurement.dart';

const _gibibyte = 1024 * 1024 * 1024;
// Flutter test workers load the app, the test isolate, and (on iOS) build
// tooling. Keep a host reserve and budget three GiB per worker so machines
// with moderate available memory can still run a small number concurrently.
const _reservedMemoryBytes = 5 * _gibibyte;
const _memoryPerWorkerBytes = 3 * _gibibyte;
const _maximumAutomaticWorkers = 4;

/// Calculates a safe default number of concurrent Flutter test processes.
///
/// Flutter test workers are heavier than ordinary Dart isolates. The default
/// reserves host capacity and considers both CPU and currently available
/// memory. An explicit CLI `--jobs` value bypasses this calculation.
int calculateAutomaticWorkerCount({
  required int testCount,
  required int logicalProcessorCount,
  int? availableMemoryBytes,
}) {
  return RunnerBenchmark.sync('worker', 'calculateAutomaticWorkerCount', () {
    if (testCount < 2) return 1;

    final processors = logicalProcessorCount.clamp(1, 1 << 20);
    final cpuBudget = ((processors - 2) ~/ 2).clamp(1, testCount);
    // If the host cannot report available memory, use the safe serial fallback.
    // This prevents an inspection failure from turning into a multi-process run
    // on a machine that may already be under memory pressure.
    if (availableMemoryBytes == null || availableMemoryBytes <= 0) return 1;

    final memoryBudget =
        ((availableMemoryBytes - _reservedMemoryBytes) ~/ _memoryPerWorkerBytes)
            .clamp(1, testCount);
    final safeBudget = cpuBudget < memoryBudget ? cpuBudget : memoryBudget;
    return safeBudget < _maximumAutomaticWorkers
        ? safeBudget
        : _maximumAutomaticWorkers;
  });
}

/// Returns memory currently available to start Flutter test workers.
///
/// macOS counts free, inactive, speculative, and purgeable pages as available;
/// Linux uses `MemAvailable`, which accounts for reclaimable cache and cgroup
/// limits where present; Windows reports currently free physical memory.
int? detectAvailableMemoryBytes() {
  try {
    if (Platform.isMacOS) return _macAvailableMemoryBytes();

    if (Platform.isLinux) {
      final availableMemory = _linuxAvailableMemoryBytes();
      final containerLimit = _linuxContainerMemoryLimitBytes();
      if (availableMemory == null) return containerLimit;
      if (containerLimit == null) return availableMemory;
      return availableMemory < containerLimit
          ? availableMemory
          : containerLimit;
    }

    if (Platform.isWindows) {
      final result = Process.runSync('powershell', const [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory',
      ]);
      if (result.exitCode == 0) {
        final kibibytes = int.tryParse(result.stdout.toString().trim());
        return kibibytes == null ? null : kibibytes * 1024;
      }
    }
  } catch (_) {
    // Host inspection is best-effort; the caller falls back to one worker.
  }
  return null;
}

int? _macAvailableMemoryBytes() {
  final result = Process.runSync('vm_stat', const []);
  if (result.exitCode != 0) return null;
  final output = result.stdout.toString();
  final pageSize = int.tryParse(
      RegExp(r'page size of (\d+) bytes').firstMatch(output)?.group(1) ?? '');
  if (pageSize == null || pageSize <= 0) return null;

  int? pages(String label) => int.tryParse(RegExp(
        '^Pages $label:\\s+(\\d+)',
        multiLine: true,
      ).firstMatch(output)?.group(1) ??
      '');

  final availablePages = (pages('free') ?? 0) +
      (pages('inactive') ?? 0) +
      (pages('speculative') ?? 0) +
      (pages('purgeable') ?? 0);
  return availablePages * pageSize;
}

int? _linuxAvailableMemoryBytes() {
  final file = File('/proc/meminfo');
  if (!file.existsSync()) return null;
  final match = RegExp(r'^MemAvailable:\s+(\d+)\s+kB$', multiLine: true)
      .firstMatch(file.readAsStringSync());
  final kibibytes = int.tryParse(match?.group(1) ?? '');
  return kibibytes == null ? null : kibibytes * 1024;
}

int? _linuxContainerMemoryLimitBytes() {
  for (final path in const [
    '/sys/fs/cgroup/memory.max',
    '/sys/fs/cgroup/memory/memory.limit_in_bytes',
  ]) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final value = file.readAsStringSync().trim();
    if (value == 'max') continue;
    final bytes = int.tryParse(value);
    if (bytes != null && bytes > 0 && bytes < (1 << 60)) return bytes;
  }
  return null;
}
