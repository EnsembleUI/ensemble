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

      var aCanceled = false;
      var bCanceled = false;
      final controllerA = StreamController<int>(onCancel: () => aCanceled = true);
      final controllerB = StreamController<int>(onCancel: () => bCanceled = true);

      providerA.trackSubscriptionForTesting(
        'liveFeed',
        controllerA.stream.listen((_) {}),
      );
      providerB.trackSubscriptionForTesting(
        'metrics',
        controllerB.stream.listen((_) {}),
      );

      providerA.dispose();

      expect(providerA.subscriptionCountForTesting, 0);
      expect(providerB.subscriptionCountForTesting, 1);
      expect(aCanceled, isTrue);
      expect(bCanceled, isFalse);

      await controllerA.close();
      await controllerB.close();
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

  group('SSEAPIProvider reconnect guards', () {
    test('disconnect prevents auto-reconnect', () async {
      final provider = SSEAPIProvider();
      await provider.disconnect('liveFeed');

      expect(
        provider.shouldReconnectForTesting('liveFeed', SSEOptions(), 0),
        isFalse,
      );
    });

    test('dispose prevents auto-reconnect', () {
      final provider = SSEAPIProvider();
      provider.dispose();

      expect(
        provider.shouldReconnectForTesting('liveFeed', SSEOptions(), 0),
        isFalse,
      );
    });

    test('honors maxReconnectAttempts', () {
      final provider = SSEAPIProvider();
      final options = SSEOptions(maxReconnectAttempts: 3);

      expect(provider.shouldReconnectForTesting('api', options, 0), isTrue);
      expect(provider.shouldReconnectForTesting('api', options, 2), isTrue);
      expect(provider.shouldReconnectForTesting('api', options, 3), isFalse);
    });

    test('shared reconnect counter stops after max error retries', () {
      final provider = SSEAPIProvider();
      final options = SSEOptions(maxReconnectAttempts: 3);
      final attempts = <int>[0];

      for (var i = 0; i < 3; i++) {
        expect(
          provider.shouldReconnectForTesting('api', options, attempts[0]),
          isTrue,
        );
        attempts[0]++;
      }

      expect(
        provider.shouldReconnectForTesting('api', options, attempts[0]),
        isFalse,
      );
    });
  });
}
