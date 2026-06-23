import 'package:meta/meta.dart';

/// Appends [params] to [url] using proper query encoding so user-controlled
/// values cannot inject additional `&key=value` pairs.
@visibleForTesting
String appendEncodedQueryParameters(String url, Map<String, String> params) {
  if (params.isEmpty) {
    return url;
  }
  final uri = Uri.parse(url);
  final merged = Map<String, String>.from(uri.queryParameters);
  merged.addAll(params);
  return uri.replace(queryParameters: merged).toString();
}
