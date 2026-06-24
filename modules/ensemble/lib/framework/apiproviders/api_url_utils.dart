import 'package:meta/meta.dart';

/// Appends [params] to [url] with percent-encoding so values cannot inject
/// additional query pairs via `&` or `=`.
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
