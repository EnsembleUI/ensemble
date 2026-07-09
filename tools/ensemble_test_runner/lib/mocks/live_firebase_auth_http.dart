import 'dart:convert';
import 'dart:io';

/// Signs in with a Firebase custom token via the Identity Toolkit REST API.
Future<Map<String, dynamic>> postIdentityToolkitSignInWithCustomToken({
  required String customToken,
  required String apiKey,
  int maxAttempts = 3,
}) async {
  Object? lastError;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      return await _postIdentityToolkitSignInOnce(
        customToken: customToken,
        apiKey: apiKey,
      );
    } catch (error) {
      lastError = error;
      final retryable = _isRetryableAuthError(error);
      if (!retryable || attempt >= maxAttempts) {
        rethrow;
      }
      await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
    }
  }
  throw lastError ?? StateError('Identity Toolkit sign-in failed.');
}

bool _isRetryableAuthError(Object error) {
  final message = error.toString().toLowerCase();
  return message.contains('connection reset') ||
      message.contains('connection closed') ||
      message.contains('timed out') ||
      message.contains('socketexception');
}

Future<Map<String, dynamic>> _postIdentityToolkitSignInOnce({
  required String customToken,
  required String apiKey,
}) async {
  final uri = Uri.parse(
    'https://identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=$apiKey',
  );
  final client = HttpClient();
  client.connectionTimeout = const Duration(seconds: 60);
  try {
    final request = await client.postUrl(uri);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.write(jsonEncode({
      'token': customToken,
      'returnSecureToken': true,
    }));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'HTTP ${response.statusCode} calling $uri: $body',
        uri: uri,
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map) {
      throw HttpException('Unexpected auth response from $uri', uri: uri);
    }
    return Map<String, dynamic>.from(decoded);
  } finally {
    client.close();
  }
}

/// Firebase ID tokens use `user_id`; custom tokens may expose `localId`.
String? uidFromFirebaseAuthResponse(Map<String, dynamic> authBody) {
  final localId = authBody['localId']?.toString();
  if (localId != null && localId.isNotEmpty) {
    return localId;
  }
  return uidFromFirebaseIdToken(authBody['idToken']?.toString() ?? '');
}

String? uidFromFirebaseIdToken(String idToken) {
  final parts = idToken.split('.');
  if (parts.length < 2) {
    return null;
  }
  try {
    final normalized = base64Url.normalize(parts[1]);
    final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
    if (payload is Map) {
      return payload['user_id']?.toString() ?? payload['sub']?.toString();
    }
  } catch (_) {
    return null;
  }
  return null;
}
