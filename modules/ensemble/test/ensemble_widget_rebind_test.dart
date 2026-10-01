import 'dart:async';

import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/framework/bindings.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/ensemble_widget.dart';
import 'package:ensemble/framework/scope.dart';
import 'package:ensemble/framework/view/data_scope_widget.dart';
import 'package:ensemble/framework/view/page.dart' as ensemble_page;
import 'package:ensemble/page_model.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble/widget/divider.dart';
import 'package:ensemble/action/bottom_sheet_actions.dart';
import 'package:ensemble/action/dialog_actions.dart';
import 'package:ensemble/framework/stub/location_manager.dart';
import 'package:ensemble/widget/helpers/controllers.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  testWidgets('closing a dialog cancels its binding subscriptions',
      (tester) async {
    final customWidgets = {
      'MyCard': loadYaml('''
inputs: [label]
body:
  Text:
    text: card-\${label}
''') as YamlMap,
    };
    late ScopeManager scope;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        scope = ScopeManager(DataContext(buildContext: context),
            PageData(customViewDefinitions: customWidgets));
        final root = scope.buildWidgetFromDefinition(loadYaml('''
Column:
  children:
    - Text:
        id: source
        text: dialog-value
'''));
        return DataScopeWidget(
            scopeManager: scope, child: Scaffold(body: root));
      }),
    ));
    await tester.pump();
    final beforeDialog = scope.listenerMap.length;
    final context = tester.element(find.byType(Scaffold));
    final dialogAction = ShowDialogAction(
      body: loadYaml('''
MyCard:
  id: dialogCard
  inputs:
    label: \${source.text}
'''),
      dismissible: true,
    );
    await dialogAction.execute(context, scope);
    await tester.pumpAndSettle();
    expect(scope.listenerMap.length, greaterThan(beforeDialog));

    Navigator.of(scope.openedDialogs.last).pop();
    await tester.pumpAndSettle();

    expect(scope.listenerMap.length, beforeDialog);
    expect(scope.openedDialogs, isEmpty);

    await dialogAction.execute(context, scope);
    await tester.pumpAndSettle();
    final source = scope.dataContext.getContextById('source') as Invokable;
    InvokableController.setProperty(source, 'text', 'reopened');
    await tester.pump();
    await tester.pump();
    expect(find.text('card-reopened'), findsOneWidget);
    Navigator.of(scope.openedDialogs.last).pop();
    await tester.pumpAndSettle();
    expect(scope.listenerMap.length, beforeDialog);
  });

  testWidgets('closing a bottom sheet cancels its binding subscriptions',
      (tester) async {
    final customWidgets = {
      'MyCard': loadYaml('''
inputs: [label]
body:
  Text:
    text: card-\${label}
''') as YamlMap,
    };
    late ScopeManager scope;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        scope = ScopeManager(DataContext(buildContext: context),
            PageData(customViewDefinitions: customWidgets));
        final root = scope.buildWidgetFromDefinition(loadYaml('''
Column:
  children:
    - Text:
        id: source
        text: sheet-value
'''));
        return DataScopeWidget(
            scopeManager: scope, child: Scaffold(body: root));
      }),
    ));
    await tester.pump();
    final beforeSheet = scope.listenerMap.length;
    final context = tester.element(find.byType(Scaffold));
    await ShowBottomSheetAction(
      body: loadYaml('''
MyCard:
  id: sheetCard
  inputs:
    label: \${source.text}
'''),
      payload: <String, dynamic>{},
    ).execute(context, scope);
    await tester.pumpAndSettle();
    expect(scope.listenerMap.length, greaterThan(beforeSheet));

    Navigator.of(tester.element(find.text('card-sheet-value'))).pop();
    await tester.pumpAndSettle();

    expect(scope.listenerMap.length, beforeSheet);
  });

  testWidgets('disposing a page scope clears page-owned listener references',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final pageData = PageData();
    final scope = ScopeManager(DataContext(buildContext: context), pageData);
    final timer = Timer(const Duration(days: 1), () {});
    scope.addTimer(StartTimerAction(onTimer: DismissDialogAction()), timer);
    final controller = EnsembleBoxController();
    PageBindingManager.retainBindingOwner(scope, controller);
    expect(PageBindingManager.debugBindingOwnerCount(pageData), 1);
    final events = StreamController<int>();
    var delivered = 0;
    final subscription = events.stream.listen((_) => delivered++);
    pageData.listenerMap[controller] = {0: subscription};
    scope.openedDialogs.add(context);

    scope.dispose();
    events.add(1);

    expect(scope.listenerMap, isEmpty);
    expect(scope.openedDialogs, isEmpty);
    expect(scope.eventBus.streamController.isClosed, isTrue);
    expect(delivered, 0);
    expect(timer.isActive, isFalse);
    expect(PageBindingManager.debugBindingOwnerCount(pageData), 0,
        reason: 'disposing the page must release owner bookkeeping');
    events.close();
  });

  testWidgets('disposing a child scope does not tear down page resources',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final pageData = PageData();
    final pageScope =
        ScopeManager(DataContext(buildContext: context), pageData);
    final childScope = pageScope.createChildScope();
    final siblingScope = pageScope.createChildScope();
    final controller = EnsembleBoxController();
    final siblingController = EnsembleBoxController();
    final timer = Timer(const Duration(days: 1), () {});
    pageScope.addTimer(StartTimerAction(onTimer: DismissDialogAction()), timer);
    final locationSubscription = Stream<LocationData>.empty().listen((_) {});
    pageScope.addLocationListener(locationSubscription);
    pageScope.dataContext.addDataContextById('local', 'page');
    childScope.dataContext.addDataContextById('local', 'child');
    siblingScope.dataContext.addDataContextById('local', 'sibling');
    pageScope.dataContext.addDataContextById('external', 'page');
    final expression =
        DataExpression(rawExpression: r'${local}', expressions: [r'${local}']);
    pageScope.registerBindingListener(
        pageScope, BindingDestination(controller, 'opacity'), expression);
    childScope.registerBindingListener(
        childScope, BindingDestination(controller, 'testId'), expression);
    siblingScope.registerBindingListener(
        siblingScope,
        BindingDestination(siblingController, 'testId'),
        expression);
    expect(pageData.listenerMap[controller], hasLength(2));
    expect(pageData.listenerMap[siblingController], hasLength(1));
    PageBindingManager.retainBindingOwner(pageScope, controller);
    PageBindingManager.retainBindingOwner(childScope, controller);
    PageBindingManager.retainBindingOwner(siblingScope, siblingController);
    final events = StreamController<int>();
    var delivered = 0;
    final subscription = events.stream.listen((_) => delivered++);
    pageData.listenerMap[controller]![0] = subscription;
    final externalController = EnsembleBoxController();
    var externalListenerFired = 0;
    pageScope.listen(
      pageScope,
      r'${external}',
      destination: BindingDestination(externalController, 'testId'),
      onDataChange: (_) => externalListenerFired++,
    );

    expect(pageData.listenerMap[controller], hasLength(3));
    childScope.dispose();
    events.add(1);
    pageScope.dispatch(ModelChangeEvent(SimpleBindingSource('external'), 'new',
        bindingScope: pageScope));
    siblingScope.dataContext.addDataContextById('local', 'new');
    siblingScope.dispatch(ModelChangeEvent(SimpleBindingSource('local'), 'new',
        bindingScope: siblingScope));
    await tester.pump();

    expect(pageScope.eventBus.streamController.isClosed, isFalse);
    expect(pageData.listenerMap, contains(controller));
    expect(pageData.listenerMap[controller], hasLength(2),
        reason:
            'child cleanup removes only its binding and keeps page and sibling listeners');
    expect(pageData.listenerMap[siblingController], hasLength(1));
    expect(delivered, 1);
    expect(siblingController.testId, 'new',
        reason: 'disposing one child must not remove a sibling binding');
    expect(externalListenerFired, 1,
        reason: 'disposing a child must not cancel another scope\'s listener');
    expect(timer.isActive, isTrue);
    expect(pageData.locationListener, same(locationSubscription));
    expect(PageBindingManager.debugBindingOwnerCount(pageData), 2,
        reason: 'only the disposing child owner should be released');

    pageScope.dispose();
    events.add(2);
    await tester.pump();
    expect(pageData.listenerMap, isEmpty);
    expect(delivered, 1);
    expect(timer.isActive, isFalse);
    expect(pageData.locationListener, isNull);
    expect(PageBindingManager.debugBindingOwnerCount(pageData), 0);
    events.close();
  });

  testWidgets('replacing a page route disposes its owning page scope',
      (tester) async {
    late ensemble_page.Page page;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: Utils.globalAppKey,
      home: Builder(builder: (context) {
        final pageModel = PageModel.fromYaml(loadYaml('''
View:
  body:
    Text:
      text: lifecycle-page
''') as YamlMap) as SinglePageModel;
        page = ensemble_page.Page(
          dataContext: DataContext(buildContext: context),
          pageModel: pageModel,
          onRendered: () {},
        );
        return page;
      }),
    ));
    await tester.pumpAndSettle();
    final pageScope = page.rootScopeManager!;
    expect(pageScope.eventBus.streamController.isClosed, isFalse);

    final pageContext = tester.element(find.byType(ensemble_page.Page));
    Navigator.of(pageContext).pushReplacement<void, void>(
      MaterialPageRoute<void>(builder: (_) => const Placeholder()),
    );
    await tester.pumpAndSettle();

    expect(pageScope.eventBus.streamController.isClosed, isTrue);
    expect(pageScope.listenerMap, isEmpty);
  });

  testWidgets('legacy child bindings do not accumulate on parent rebuilds',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final ctx = tester.element(find.byType(SizedBox));
    final scope = ScopeManager(DataContext(buildContext: ctx), PageData());
    final root = scope.buildWidgetFromDefinition(loadYaml('''
Column:
  children:
    - Column:
        id: box
        children:
          - Text:
              text: \${source.text}
    - Text:
        id: source
        text: initial
'''));
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: DataScopeWidget(scopeManager: scope, child: root))));
    await tester.pump();

    final box = scope.dataContext.getContextById('box') as Invokable;
    final initialListenerCount = scope.listenerMap.length;
    for (var i = 0; i < 10; i++) {
      InvokableController.setProperty(box, 'gap', i + 1);
      await tester.pump();
    }

    expect(scope.listenerMap.length, initialListenerCount,
        reason:
            'rebuilding a legacy container should not retain replaced children');
    final source = scope.dataContext.getContextById('source') as Invokable;
    InvokableController.setProperty(source, 'text', 'updated');
    await tester.pump();
    await tester.pump();
    expect(find.text('updated'), findsNWidgets(2));
  });

  testWidgets('legacy binding stays until the final shared widget owner leaves',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final scope = ScopeManager(DataContext(buildContext: context), PageData());
    final legacyWidget = EnsembleDivider();
    scope.registerBindingListener(
      scope,
      BindingDestination(legacyWidget, 'gap'),
      DataExpression(rawExpression: r'${local}', expressions: [r'${local}']),
    );

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(
        scopeManager: scope,
        child: Row(children: [legacyWidget, legacyWidget]),
      ),
    ));
    expect(scope.listenerMap, contains(legacyWidget));

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: scope, child: legacyWidget),
    ));
    expect(scope.listenerMap, contains(legacyWidget),
        reason: 'disposing one EWidgetState must not cancel its shared peer');

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(scope.listenerMap, isNot(contains(legacyWidget)),
        reason: 'the last legacy owner should release the binding');
  });

  testWidgets('legacy binding follows a scope change on the same page',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final pageData = PageData();
    final firstScope =
        ScopeManager(DataContext(buildContext: context), pageData);
    final secondScope =
        ScopeManager(DataContext(buildContext: context), pageData);
    firstScope.dataContext.addDataContextById('local', 1.0);
    secondScope.dataContext.addDataContextById('local', 2.0);
    final widget = EnsembleDivider();
    final expression =
        DataExpression(rawExpression: r'${local}', expressions: [r'${local}']);
    firstScope.registerBindingListener(
        firstScope, BindingDestination(widget, 'gap'), expression);

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: firstScope, child: widget),
    ));
    secondScope.registerBindingListener(
        secondScope, BindingDestination(widget, 'gap'), expression);
    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: secondScope, child: widget),
    ));

    firstScope.dispatch(ModelChangeEvent(SimpleBindingSource('local'), 3.0,
        bindingScope: firstScope));
    secondScope.dispatch(ModelChangeEvent(SimpleBindingSource('local'), 4.0,
        bindingScope: secondScope));
    await tester.pump();
    expect(widget.controller.gap, 2.0);
    expect(pageData.listenerMap[widget], hasLength(1));
  });

  testWidgets('legacy scope change does not restore the previous scope binding',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final pageData = PageData();
    final firstScope =
        ScopeManager(DataContext(buildContext: context), pageData);
    final secondScope =
        ScopeManager(DataContext(buildContext: context), pageData);
    firstScope.dataContext.addDataContextById('local', 1.0);
    final widget = EnsembleDivider();
    final oldSource =
        BindingSource.getBindingSources(r'${local}', firstScope.dataContext)
            .single;
    firstScope.registerBindingListener(
      firstScope,
      BindingDestination(widget, 'gap'),
      DataExpression(rawExpression: r'${local}', expressions: [r'${local}']),
    );

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: firstScope, child: widget),
    ));
    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: secondScope, child: widget),
    ));

    firstScope.dataContext.addDataContextById('local', 3.0);
    firstScope
        .dispatch(ModelChangeEvent(oldSource, 3.0, bindingScope: firstScope));
    await tester.pump();

    expect(widget.controller.gap, isNull,
        reason: 'a legacy state must not restore/evaluate its previous scope');
    expect(pageData.listenerMap[widget], isNull);
  });

  testWidgets('scope change without replacement drops the old binding',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final pageData = PageData();
    final firstScope =
        ScopeManager(DataContext(buildContext: context), pageData);
    final secondScope =
        ScopeManager(DataContext(buildContext: context), pageData);
    firstScope.dataContext.addDataContextById('local', 'first');
    final controller = EnsembleBoxController()..testId = 'seed';
    final expression =
        DataExpression(rawExpression: r'${local}', expressions: [r'${local}']);
    final oldSource =
        BindingSource.getBindingSources(r'${local}', firstScope.dataContext)
            .single;
    firstScope.registerBindingListener(
        firstScope, BindingDestination(controller, 'testId'), expression);

    final probe = _BindingOwnerProbe(controller);
    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: firstScope, child: probe),
    ));
    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: secondScope, child: probe),
    ));

    firstScope.dataContext.addDataContextById('local', 'stale');
    firstScope.dispatch(
        ModelChangeEvent(oldSource, 'stale', bindingScope: firstScope));
    await tester.pump();

    expect(controller.testId, 'seed');
    expect(pageData.listenerMap[controller], isNull);
  });

  testWidgets('replacing a binding expression cancels the previous source',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final scope = ScopeManager(DataContext(buildContext: context), PageData());
    scope.dataContext.addDataContextById('first', 'initial-first');
    scope.dataContext.addDataContextById('second', 'initial-second');
    final controller = EnsembleBoxController()..testId = 'seed';
    scope.registerBindingListener(
      scope,
      BindingDestination(controller, 'testId'),
      DataExpression(rawExpression: r'${first}', expressions: [r'${first}']),
    );
    scope.registerBindingListener(
      scope,
      BindingDestination(controller, 'testId'),
      DataExpression(rawExpression: r'${second}', expressions: [r'${second}']),
    );
    expect(scope.listenerMap[controller], hasLength(1));

    scope.dataContext.addDataContextById('second', 'updated-second');
    final firstSource =
        BindingSource.getBindingSources(r'${first}', scope.dataContext).single;
    scope.dispatch(
        ModelChangeEvent(firstSource, 'ignored', bindingScope: scope));
    expect(controller.testId, 'seed',
        reason: 'updates from the replaced source must no longer be observed');

    final secondSource =
        BindingSource.getBindingSources(r'${second}', scope.dataContext).single;
    scope.dispatch(
        ModelChangeEvent(secondSource, 'updated-second', bindingScope: scope));
    await tester.pump();
    expect(controller.testId, 'updated-second');

    scope.removeBindingListenersForScope(controller, scope);
    expect(scope.listenerMap[controller], isNull);
  });

  testWidgets('new widget binding stays until the final shared owner leaves',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final scope = ScopeManager(DataContext(buildContext: context), PageData());
    final controller = EnsembleBoxController();
    scope.registerBindingListener(
      scope,
      BindingDestination(controller, 'testId'),
      DataExpression(rawExpression: r'${local}', expressions: [r'${local}']),
    );

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(
        scopeManager: scope,
        child: Row(children: [
          _BindingOwnerProbe(controller),
          _BindingOwnerProbe(controller),
        ]),
      ),
    ));
    expect(scope.listenerMap, contains(controller));

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(
        scopeManager: scope,
        child: _BindingOwnerProbe(controller),
      ),
    ));
    expect(scope.listenerMap, contains(controller),
        reason: 'disposing one owner must preserve the shared controller');

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    expect(scope.listenerMap, isNot(contains(controller)));
  });

  testWidgets('restoration fills in a missing property subscription',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final scope = ScopeManager(DataContext(buildContext: context), PageData());
    scope.dataContext.addDataContextById('local', 'initial');
    final controller = EnsembleBoxController();
    final expression =
        DataExpression(rawExpression: r'${local}', expressions: [r'${local}']);
    scope.registerBindingListener(
        scope, BindingDestination(controller, 'testId'), expression);
    scope.registerBindingListener(
        scope, BindingDestination(controller, 'opacity'), expression);
    expect(scope.listenerMap[controller], hasLength(2));

    final source =
        BindingSource.getBindingSources(r'${local}', scope.dataContext).single;
    final missingHash = scope.getHash(
        destinationSetter: 'testId', source: source, scopeManager: scope);
    scope.listenerMap[controller]!.remove(missingHash)!.cancel();
    expect(scope.listenerMap[controller], hasLength(1));

    scope.restoreBindingListeners(controller);
    expect(scope.listenerMap[controller], hasLength(2));
  });

  testWidgets('custom widget with id keeps input bindings after parent rebuild',
      (tester) async {
    final customWidgets = {
      'MyCard': loadYaml('''
inputs: [label]
body:
  Text:
    text: card-\${label}
''') as YamlMap,
    };
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final ctx = tester.element(find.byType(SizedBox));
    final scope = ScopeManager(DataContext(buildContext: ctx),
        PageData(customViewDefinitions: customWidgets));
    final root = scope.buildWidgetFromDefinition(loadYaml('''
Column:
  children:
    - Text:
        id: source
        text: first
    - Column:
        id: box
        children:
          - MyCard:
              id: card
              inputs:
                label: \${source.text}
'''));
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: DataScopeWidget(scopeManager: scope, child: root))));
    await tester.pump();
    expect(find.text('card-first'), findsOneWidget);

    final box = scope.dataContext.getContextById('box') as Invokable;
    final source = scope.dataContext.getContextById('source') as Invokable;
    InvokableController.setProperty(box, 'gap', 8);
    await tester.pump();
    await tester.pump();

    InvokableController.setProperty(source, 'text', 'second');
    await tester.pump();
    await tester.pump();

    expect(find.text('card-second'), findsOneWidget,
        reason:
            'custom widget input binding should use the current child scope');
  });

  testWidgets('scope switch on the same page preserves controller bindings',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final buildContext = tester.element(find.byType(Placeholder));
    final pageData = PageData();
    final firstScope =
        ScopeManager(DataContext(buildContext: buildContext), pageData);
    final secondScope =
        ScopeManager(DataContext(buildContext: buildContext), pageData);
    final controller = EnsembleBoxController();
    final widget = _BindingOwnerProbe(controller);
    firstScope.dataContext.addDataContextById('local', 'first');
    secondScope.dataContext.addDataContextById('local', 'second');
    final expression =
        DataExpression(rawExpression: '\${local}', expressions: ['\${local}']);
    firstScope.registerBindingListener(
        firstScope, BindingDestination(controller, 'testId'), expression);

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: firstScope, child: widget),
    ));
    // YAML bindings for the new model are registered before its state builds.
    secondScope.registerBindingListener(
        secondScope, BindingDestination(controller, 'testId'), expression);
    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: secondScope, child: widget),
    ));
    expect(pageData.listenerMap, contains(controller));
    expect(pageData.listenerMap[controller], hasLength(1));
    secondScope.dataContext.addDataContextById('local', 'new');
    secondScope.dispatch(ModelChangeEvent(DeferredBindingSource('local'), 'new',
        bindingScope: secondScope));
    await tester.pump();
    expect(controller.testId, 'new');
    firstScope.dataContext.addDataContextById('local', 'stale');
    firstScope.dispatch(ModelChangeEvent(
        DeferredBindingSource('local'), 'stale',
        bindingScope: firstScope));
    await tester.pump();
    expect(controller.testId, 'new');
  });

  testWidgets('replacing a controller removes its old binding entry',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final buildContext = tester.element(find.byType(Placeholder));
    final scope =
        ScopeManager(DataContext(buildContext: buildContext), PageData());
    final oldController = EnsembleBoxController();
    final newController = EnsembleBoxController();
    scope.listenerMap[oldController] = {};

    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(
        scopeManager: scope,
        child: _BindingOwnerProbe(oldController, key: const ValueKey('probe')),
      ),
    ));
    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(
        scopeManager: scope,
        child: _BindingOwnerProbe(newController, key: const ValueKey('probe')),
      ),
    ));

    expect(scope.listenerMap, isNot(contains(oldController)));
  });

  testWidgets(
      'templated custom widget keeps its input binding after parent hide/show',
      (tester) async {
    final customWidgets = {
      'MyCard': loadYaml('''
inputs: [label]
body:
  Text:
    text: card-\${label}
''') as YamlMap,
    };

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    final ctx = tester.element(find.byType(SizedBox));
    final scope = ScopeManager(DataContext(buildContext: ctx),
        PageData(customViewDefinitions: customWidgets));
    final root = scope.buildWidgetFromDefinition(loadYaml('''
Column:
  children:
    - Text:
        id: src
        text: a
    - Column:
        id: box
        item-template:
          data: \${[1]}
          name: it
          template:
            MyCard:
              inputs:
                label: \${src.text}
'''));
    await tester.pumpWidget(MaterialApp(
        home:
            Scaffold(body: DataScopeWidget(scopeManager: scope, child: root))));
    await tester.pump();
    expect(find.text('card-a'), findsOneWidget);

    final src = scope.dataContext.getContextById('src') as Invokable;
    final box = scope.dataContext.getContextById('box') as Invokable;

    Future<void> settle() async {
      await tester.pump();
      await tester.pump();
    }

    InvokableController.setProperty(src, 'text', 'b');
    await settle();
    expect(find.text('card-b'), findsOneWidget);

    InvokableController.setProperty(box, 'visible', false);
    await settle();
    expect(find.text('card-b'), findsNothing);
    InvokableController.setProperty(box, 'visible', true);
    await settle();
    expect(find.text('card-b'), findsOneWidget);

    InvokableController.setProperty(src, 'text', 'c');
    await settle();
    expect(find.text('card-c'), findsOneWidget,
        reason: 'custom widget input binding lost after hide/show');
  });

  testWidgets('disposing a widget cancels its direct listen() subscriptions',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    final context = tester.element(find.byType(Placeholder));
    final scope = ScopeManager(DataContext(buildContext: context), PageData());
    scope.dataContext.addDataContextById('local', 1.0);
    final widget = EnsembleDivider();
    var fired = 0;

    // Conditional/TabBar subscribe through listen() directly, bypassing
    // registerBindingListener.
    scope.listen(
      scope,
      r'${local}',
      destination: BindingDestination(widget, 'gap'),
      onDataChange: (_) => fired++,
    );
    await tester.pumpWidget(MaterialApp(
      home: DataScopeWidget(scopeManager: scope, child: widget),
    ));

    final source =
        BindingSource.getBindingSources(r'${local}', scope.dataContext).single;
    scope.dispatch(ModelChangeEvent(source, 2.0, bindingScope: scope));
    await tester.pump();
    expect(fired, 1, reason: 'listener should fire while mounted');

    await tester.pumpWidget(const MaterialApp(home: Placeholder()));
    scope.dispatch(ModelChangeEvent(source, 3.0, bindingScope: scope));
    await tester.pump();
    expect(fired, 1,
        reason: 'direct listen() subscriptions must be cancelled on dispose');
    expect(scope.listenerMap, isNot(contains(widget)));
  });
}

class _BindingOwnerProbe extends EnsembleWidget<EnsembleWidgetController> {
  const _BindingOwnerProbe(super.controller, {super.key});

  @override
  State<_BindingOwnerProbe> createState() => _BindingOwnerProbeState();
}

class _BindingOwnerProbeState extends EnsembleWidgetState<_BindingOwnerProbe> {
  @override
  Widget buildWidget(BuildContext context) => const SizedBox();
}
