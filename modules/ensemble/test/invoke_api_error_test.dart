import 'package:ensemble/action/invoke_api_action.dart';
import 'package:ensemble/framework/apiproviders/firestore/firestore_api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isStructuredApiErrorResponse', () {
    test('accepts HTTP and Firestore API responses', () {
      expect(
        isStructuredApiErrorResponse(HttpResponse.fromBody('error', null, 500)),
        isTrue,
      );
      expect(isStructuredApiErrorResponse(FirestoreResponse()), isTrue);
    });

    test('rejects generic errors and primitives', () {
      expect(isStructuredApiErrorResponse(StateError('boom')), isFalse);
      expect(isStructuredApiErrorResponse('network down'), isFalse);
      expect(isStructuredApiErrorResponse(null), isFalse);
    });
  });
}
