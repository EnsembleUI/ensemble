import 'dart:io';

const _gibibyte = 1024 * 1024 * 1024;
const _reservedMemoryBytes = 4 * _gibibyte;
const _memoryPerWorkerBytes = 3 * _gibibyte;

/// Calculates a safe default number of concurrent Flutter test processes.
///
/// Flutter test workers are heavier than ordinary Dart isolates. The default
/// therefore reserves host capacity and considers both CPU and physical memory.
/// An explicit CLI `--jobs` value bypasses this calculation.
int calculateAutomaticWorkerCount({
  required int testCount,
  required int logicalProcessorCount,
  int? totalMemoryBytes,
}) {
  if (testCount < 2) return 1;

  final processors = logicalProcessorCount.clamp(1, 1 << 20);
  final cpuBudget = ((processors - 2) ~/ 2).clamp(1, testCount);
  if (totalMemoryBytes == null || totalMemoryBytes <= 0) {
    return cpuBudget;
  }

  final memoryBudget =
      ((totalMemoryBytes - _reservedMemoryBytes) ~/ _memoryPerWorkerBytes)
          .clamp(1, testCount);
  return cpuBudget < memoryBudget ? cpuBudget : memoryBudget;
}

/// Returns total physical memory, constrained by a Linux container limit when
/// one is present. Failure to inspect the host is safe: CPU capacity is used.
int? detectTotalMemoryBytes() {
  try {
    if (Platform.isMacOS) {
      final result = Process.runSync('sysctl', const ['-n', 'hw.memsize']);
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim());
      }
    }

    if (Platform.isLinux) {
      final physicalMemory = _linuxPhysicalMemoryBytes();
      final containerLimit = _linuxContainerMemoryLimitBytes();
      if (physicalMemory == null) return containerLimit;
      if (containerLimit == null) return physicalMemory;
      return physicalMemory < containerLimit ? physicalMemory : containerLimit;
    }

    if (Platform.isWindows) {
      final result = Process.runSync('powershell', const [
        '-NoProfile',
        '-Command',
        '(Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory',
      ]);
      if (result.exitCode == 0) {
        return int.tryParse(result.stdout.toString().trim());
      }
    }
  } catch (_) {
    // Host inspection is best-effort; CPU capacity remains a safe fallback.
  }
  return null;
}

int? _linuxPhysicalMemoryBytes() {
  final file = File('/proc/meminfo');
  if (!file.existsSync()) return null;
  final match = RegExp(r'^MemTotal:\s+(\d+)\s+kB$', multiLine: true)
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
