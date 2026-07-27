import 'dart:io';

import 'package:ensemble/framework/widget/colored_box_placeholder.dart';
import 'package:ensemble/widget/image.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'test_utils.dart';

class _RedirectResponseClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      const Stream<List<int>>.empty(),
      HttpStatus.movedTemporarily,
      headers: {HttpHeaders.locationHeader: '/image.gif'},
    );
  }
}

void main() {
  group('EnsembleImage headers', () {
    test('headers setter coerces keys and values to strings', () {
      final image = EnsembleImage();
      image.setProperty('headers', {
        'Authorization': 'Bearer token',
        123: 456,
      });

      expect(image.controller.headers, {
        'Authorization': 'Bearer token',
        '123': '456',
      });
      expect(image.getters()['headers']?.call(), image.controller.headers);
    });

    test('headers setter clears when value is not a map', () {
      final image = EnsembleImage();
      image.setProperty('headers', {'X-Test': '1'});
      image.setProperty('headers', null);

      expect(image.controller.headers, isNull);
    });
  });

  testWidgets('shows placeholder when source is empty', (tester) async {
    final image = EnsembleImage();
    image.setProperty('source', '   ');

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(image));

    expect(find.byType(ColoredBoxPlaceholder), findsOneWidget);
  });

  test('redirect-blocking client throws on redirects', () async {
    final client = RedirectBlockingHttpClient(client: _RedirectResponseClient());

    addTearDown(client.close);

    expect(
      () => client.get(Uri.parse('https://example.com/redirect.png')),
      throwsA(isA<http.ClientException>()),
    );
  });
}
