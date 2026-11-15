import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ensemble/framework/widget/colored_box_placeholder.dart';
import 'package:ensemble/widget/avatar.dart';
import 'package:ensemble/widget/image.dart';
import 'package:flutter/painting.dart';
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

  group('EnsembleImage redirects', () {
    test('allowRedirect defaults to true and can be disabled', () {
      final image = EnsembleImage();

      expect(image.controller.allowRedirect, isTrue);

      image.setProperty('allowRedirect', false);

      expect(image.controller.allowRedirect, isFalse);
    });

    test('redirect-blocking client throws on redirects', () async {
      final client =
          RedirectBlockingHttpClient(client: _RedirectResponseClient());

      addTearDown(client.close);

      expect(
        () => client.get(Uri.parse('https://example.com/redirect.png')),
        throwsA(isA<http.ClientException>()),
      );
    });
  });

  group('filterQuality', () {
    const networkSource = 'https://example.com/logo.png';

    test('Image defaults to null and parses valid values', () {
      final image = EnsembleImage();
      expect(image.controller.filterQuality, isNull);
      expect(image.getters()['filterQuality']?.call(), isNull);

      image.setProperty('filterQuality', 'medium');
      expect(image.controller.filterQuality, FilterQuality.medium);
      expect(image.getters()['filterQuality']?.call(), 'medium');

      image.setProperty('filterQuality', 'invalid');
      expect(image.controller.filterQuality, isNull);
    });

    testWidgets('Image keeps low for network images when not set',
        (tester) async {
      final image = EnsembleImage();
      image.setProperty('source', networkSource);

      await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(image));

      final cached =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(cached.filterQuality, FilterQuality.low);
    });

    testWidgets('Image applies the configured value to network images',
        (tester) async {
      final image = EnsembleImage();
      image.setProperty('source', networkSource);
      image.setProperty('filterQuality', 'medium');

      await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(image));

      final cached =
          tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));
      expect(cached.filterQuality, FilterQuality.medium);
    });

    testWidgets('Avatar keeps low by default and applies the configured value',
        (tester) async {
      final defaultController = AvatarController()
        ..setProperty('source', networkSource);
      await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
          Avatar.build(defaultController)));
      expect(
          tester
              .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
              .filterQuality,
          FilterQuality.low);

      final mediumController = AvatarController()
        ..setProperty('source', networkSource)
        ..setProperty('filterQuality', 'medium');
      await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(
          Avatar.build(mediumController)));
      expect(
          tester
              .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
              .filterQuality,
          FilterQuality.medium);
    });
  });

  testWidgets('shows placeholder when source is empty', (tester) async {
    final image = EnsembleImage();
    image.setProperty('source', '   ');

    await tester.pumpWidget(TestUtils.wrapTestWidgetWithScope(image));

    expect(find.byType(ColoredBoxPlaceholder), findsOneWidget);
  });
}
