import 'dart:async';

import 'package:ensemble/framework/apiproviders/firestore/firestore_api_provider.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('replaceFirestoreApiSubscription', () {
    test('cancels prior subscription for the same apiName', () async {
      final firstController = StreamController<int>();
      final secondController = StreamController<int>();
      var firstEventsAfterReplace = 0;

      final first = firstController.stream.listen((_) {
        firstEventsAfterReplace++;
      });
      final second = secondController.stream.listen((_) {});

      final subscriptions = <String, StreamSubscription>{'users': first};
      replaceFirestoreApiSubscription(subscriptions, 'users', second);

      firstController.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(firstEventsAfterReplace, 0);
      expect(subscriptions['users'], same(second));
      expect(first.isPaused, isFalse);

      await firstController.close();
      await secondController.close();
    });

    test('keeps subscriptions for different api names', () async {
      final usersController = StreamController<int>();
      final ordersController = StreamController<int>();
      final users = usersController.stream.listen((_) {});
      final orders = ordersController.stream.listen((_) {});

      final subscriptions = <String, StreamSubscription>{'users': users};
      replaceFirestoreApiSubscription(subscriptions, 'orders', orders);

      expect(subscriptions.keys, containsAll(['users', 'orders']));

      await usersController.close();
      await ordersController.close();
    });
  });

  group('event bus dispose race', () {
    test('closed event bus rejects new events', () {
      final bus = EventBus();
      bus.destroy();
      expect(bus.streamController.isClosed, isTrue);
      expect(() => bus.fire('event'), throwsStateError);
    });
  });
}
