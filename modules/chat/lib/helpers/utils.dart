/// Utility helpers for chat internals.
library utils;

import 'dart:math' as math;

/// Generates a random alpha-numeric string.
String generateRandomString({int length = 8}) {
  const randomChars =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const charsLength = randomChars.length;

  final rand = math.Random();
  final codeUnits = List.generate(
    length,
    (index) => randomChars[rand.nextInt(charsLength)].codeUnitAt(0),
  );

  return String.fromCharCodes(codeUnits);
}
