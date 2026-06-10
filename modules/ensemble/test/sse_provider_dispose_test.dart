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
}
