bool getTestMode() {
  return const String.fromEnvironment("testmode").toLowerCase() == 'true';
}
