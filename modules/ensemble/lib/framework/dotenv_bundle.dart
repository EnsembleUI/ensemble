import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Parses `.env`-style text (e.g. from `rootBundle`) using [Parser] from
/// `flutter_dotenv` — same rules as [LocalDefinitionProvider] and
/// [Ensemble.initialize] for quoted values, `\\"`, and `=` inside values.
Map<String, String> parseDotEnvBundleContent(String content) {
  const Parser parser = Parser();
  final Map<String, String> result = <String, String>{};
  for (final String rawLine in content.split(RegExp(r'\r?\n'))) {
    final String line = rawLine.replaceAll('\r', '');
    final Map<String, String> kv =
        parser.parseOne(line, envMap: Map<String, String>.from(result));
    if (kv.isNotEmpty) {
      final String key = kv.keys.single;
      final String value = kv.values.single;
      result[key] = value;
    }
  }
  return result;
}
