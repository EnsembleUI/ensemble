import 'dart:math';

class BridgeUtils {
  static const domain = 'walletconnect.org';

  static final bridges = 'abcdefghijklmnopqrstuvwxyz0123456789'
      .split('')
      .map((char) => 'https://$char.bridge.walletconnect.org')
      .toList(growable: false);

  static bool shouldSelectRandomly(String url) {
    final uri = Uri.parse(url);
    final parts = uri.host.split('.');
    final parsedDomain = parts.sublist(parts.length - 2).join('.');
    return parsedDomain == domain;
  }

  static String selectRandomBridgeUrl() {
    final random = Random();
    final randomBridgeIndex = random.nextInt(bridges.length);
    final x = bridges[randomBridgeIndex];
    return x;
  }

  static String getBridgeUrl(String url) {
    if (shouldSelectRandomly(url)) {
      return selectRandomBridgeUrl();
    }
    return url;
  }
}
