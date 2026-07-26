import 'dart:convert';

import 'package:ensemble_test_runner/mocks/live_firebase_auth_http.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('extracts Firebase uid from idToken payload', () {
    const uid = 'test-user-uid';
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'user_id': uid,
      'sub': uid,
    })));
    final idToken = 'header.$payload.signature';
    expect(uidFromFirebaseIdToken(idToken), uid);
  });
}
