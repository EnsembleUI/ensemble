import 'dart:io';

/// Resolves the host address devices should use to reach host-owned services.
///
/// Android emulators/USB devices use `adb reverse` and keep loopback URLs.
/// iOS simulators can use `127.0.0.1`. Physical iPhones need a LAN IPv4.
Future<String?> resolveIntegrationHostAddress({
  required String platform,
  required bool emulator,
  String? explicitHostAddress,
}) async {
  if (explicitHostAddress != null && explicitHostAddress.isNotEmpty) {
    return explicitHostAddress;
  }
  if (platform == 'android') {
    // adb reverse maps device loopback to the host.
    return null;
  }
  if (platform == 'ios' && emulator) {
    return null;
  }
  if (platform == 'ios' && !emulator) {
    final lan = await firstLanIpv4Address();
    if (lan == null) {
      throw StateError(
        'Physical iOS devices cannot reach host services via 127.0.0.1. '
        'Connect the Mac and iPhone to the same network, or pass '
        '--host-address=<lan-ip>. USB-only networking is not supported yet.',
      );
    }
    return lan;
  }
  return null;
}

/// Rewrites loopback hosts in [url] to [hostAddress] when set.
String? rewriteServiceUrlForDevice(String? url, String? hostAddress) {
  if (url == null || hostAddress == null || hostAddress.isEmpty) return url;
  final uri = Uri.tryParse(url);
  if (uri == null) return url;
  if (uri.host != '127.0.0.1' && uri.host != 'localhost') return url;
  return uri.replace(host: hostAddress).toString();
}

Future<String?> firstLanIpv4Address() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final entry in interfaces) {
      for (final address in entry.addresses) {
        if (address.isLoopback) continue;
        final ip = address.address;
        if (ip.startsWith('169.254.')) continue;
        return ip;
      }
    }
  } catch (_) {}
  return null;
}
