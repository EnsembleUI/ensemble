import 'dart:async';

import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/apiproviders/sse_api_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SSEAPIProvider.dispose', () {
    test('cancels only this instance subscriptions', () async {
      final providerA = SSEAPIProvider();
      final providerB = SSEAPIProvider();

      final controllerA = StreamController<int>();
      final controllerB = StreamController<int>();
      var aCanceled = false;
      var bCanceled = false;

      providerA.trackSubscriptionForTesting(
        'liveFeed',
        controllerA.stream.listen((_) {}, onDone: () => aCanceled = true),
      );
      providerB.trackSubscriptionForTesting(
        'metrics',
        controllerB.stream.listen((_) {}, onDone: () => bCanceled = true),
      );

      providerA.dispose();

      expect(providerA.subscriptionCountForTesting, 0);
      expect(providerB.subscriptionCountForTesting, 1);

      await controllerA.close();
      await controllerB.close();

      expect(aCanceled, isTrue);
      expect(bCanceled, isFalse);
    });
  });

  group('APIProviders.getProvider', () {
    test('returns cloned sse provider from screen map', () {
      final sse = SSEAPIProvider();
      final providers = APIProviders(
        providers: {'sse': sse, 'http': HTTPAPIProvider()},
        child: const SizedBox.shrink(),
      );

      expect(identical(providers.getProvider('sse'), sse), isTrue);
    });
  });
}
