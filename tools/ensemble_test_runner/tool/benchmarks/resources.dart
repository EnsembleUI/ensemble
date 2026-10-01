import 'dart:ffi';
import 'dart:io';

typedef _UsageNative = Int32 Function(Int32, Pointer<Void>);
typedef _Usage = int Function(int, Pointer<Void>);
typedef _MallocNative = Pointer<Void> Function(IntPtr);
typedef _Malloc = Pointer<Void> Function(int);
typedef _FreeNative = Void Function(Pointer<Void>);
typedef _Free = void Function(Pointer<Void>);

/// Process CPU time (user + system), read only before/after a case.
/// macOS timeval uses a 32-bit microsecond field plus alignment padding;
/// Linux uses a native long. Both layouts occupy 16 bytes on 64-bit hosts.
int? processCpuMicroseconds() {
  if ((!Platform.isLinux && !Platform.isMacOS) || sizeOf<IntPtr>() != 8)
    return null;
  try {
    final libc = DynamicLibrary.process();
    final malloc = libc.lookupFunction<_MallocNative, _Malloc>('malloc');
    final free = libc.lookupFunction<_FreeNative, _Free>('free');
    final usage = libc.lookupFunction<_UsageNative, _Usage>('getrusage');
    final memory = malloc(256);
    if (memory == nullptr) return null;
    try {
      if (usage(0, memory) != 0) return null;
      final fields = memory.cast<Int64>();
      final userUs = Platform.isMacOS ? fields[1] & 0xffffffff : fields[1];
      final systemUs = Platform.isMacOS ? fields[3] & 0xffffffff : fields[3];
      return (fields[0] + fields[2]) * 1000000 + userUs + systemUs;
    } finally {
      free(memory);
    }
  } catch (_) {
    return null;
  }
}
