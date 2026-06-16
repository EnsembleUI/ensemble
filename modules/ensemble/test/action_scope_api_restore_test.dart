import 'package:ensemble/action/action_scope_util.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:yaml/yaml.dart';

class _MockBuildContext extends Mock implements BuildContext {}

void main() {
  group('reusable action scoped API restore', () {
    late ScopeManager scopeManager;
    late YamlMap pageApi;
    late YamlMap actionApi;

    setUp(() {
      pageApi = YamlMap.wrap({
        'url': 'https://example.com/page',
        'method': 'GET',
      });
      actionApi = YamlMap.wrap({
        'url': 'https://example.com/action',
        'method': 'POST',
      });

      scopeManager = ScopeManager(
        DataContext(buildContext: _MockBuildContext()),
        PageData(apiMap: {'sharedApi': pageApi}),
      );
    });

    test('removes action-only APIs after restore', () {
      final snapshot = ActionScopeUtil.snapshotPageApisForAction(
        scopeManager,
        {'actionOnly': actionApi},
      );

      scopeManager.pageData.apiMap!.addAll({'actionOnly': actionApi});
      expect(scopeManager.pageData.apiMap!.containsKey('actionOnly'), isTrue);

      ActionScopeUtil.restorePageApisAfterAction(scopeManager, snapshot);

      expect(scopeManager.pageData.apiMap!.containsKey('actionOnly'), isFalse);
      expect(scopeManager.pageData.apiMap!['sharedApi'], same(pageApi));
    });

    test('restores page APIs overwritten by action-scoped names', () {
      final snapshot = ActionScopeUtil.snapshotPageApisForAction(
        scopeManager,
        {'sharedApi': actionApi},
      );

      scopeManager.pageData.apiMap!['sharedApi'] = actionApi;
      expect(
        scopeManager.pageData.apiMap!['sharedApi']!['url'],
        'https://example.com/action',
      );

      ActionScopeUtil.restorePageApisAfterAction(scopeManager, snapshot);

      expect(scopeManager.pageData.apiMap!['sharedApi'], same(pageApi));
    });

    test('prepareScope merge is undone by restore', () {
      final definition = YamlMap.wrap({
        'API': {
          'actionOnly': actionApi,
          'sharedApi': actionApi,
        },
        'body': {
          'showToast': {'message': 'done'},
        },
      });

      final snapshot = ActionScopeUtil.snapshotPageApisForAction(
        scopeManager,
        ActionScopeUtil.parseApiMap(definition),
      );

      ActionScopeUtil.prepareScope(
        parentScope: scopeManager,
        definition: definition,
        parameters: const [],
      );

      expect(scopeManager.pageData.apiMap!.keys, containsAll(['actionOnly']));
      expect(
        scopeManager.pageData.apiMap!['sharedApi']!['url'],
        'https://example.com/action',
      );

      ActionScopeUtil.restorePageApisAfterAction(scopeManager, snapshot);

      expect(scopeManager.pageData.apiMap!.containsKey('actionOnly'), isFalse);
      expect(scopeManager.pageData.apiMap!['sharedApi'], same(pageApi));
    });
  });

  group('executeAction async restore timing', () {
    Future<List<String>> runWithFinally({required bool awaitInner}) async {
      final order = <String>[];

      Future<void> inner() async {
        await Future<void>.delayed(const Duration(milliseconds: 20));
        order.add('inner');
      }

      try {
        if (awaitInner) {
          await inner();
        } else {
          // Mirrors ExecuteActionAction returning executeActionWithScope
          // without await: finally runs before the inner Future completes.
          // ignore: unawaited_futures
          inner();
        }
      } finally {
        order.add('restore');
      }
      return order;
    }

    test('restore runs before inner work without await', () async {
      final order = await runWithFinally(awaitInner: false);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(order.first, 'restore');
      expect(order.last, 'inner');
    });

    test('restore runs after inner work with await', () async {
      final order = await runWithFinally(awaitInner: true);
      expect(order, ['inner', 'restore']);
    });
  });
}
