import 'package:ensemble/framework/screen_tracker.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:ensemble/navigation/browser/navigation_browser_history.dart';
import 'package:ensemble/navigation/ensemble_navigation_manager.dart';
import 'package:ensemble/navigation/ensemble_route_factory.dart';
import 'package:ensemble/navigation/navigation_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final manager = EnsembleNavigationManager.instance;

  EnsembleRouteDescriptor descriptor(String name,
          {Map<String, dynamic>? inputs}) =>
      EnsembleRouteDescriptor(screenName: name, inputs: inputs);

  PageRouteBuilder<dynamic> routeFor(EnsembleRouteDescriptor descriptor,
      {Widget? child, Duration transitionDuration = Duration.zero}) {
    return PageRouteBuilder<dynamic>(
      settings: EnsembleRouteSettings(
        descriptor: descriptor,
        payload: descriptor.toPayload(),
      ),
      transitionDuration: transitionDuration,
      reverseTransitionDuration: transitionDuration,
      pageBuilder: (_, __, ___) =>
          child ?? Scaffold(body: Text(descriptor.identifier)),
    );
  }

  Future<GlobalKey<NavigatorState>> pumpApp(
    WidgetTester tester, {
    NavigationBrowserHistory? browserHistory,
    Map<String, dynamic>? homeInputs,
    bool trackScreens = false,
  }) async {
    manager.reset();
    ScreenTracker().clearAll();
    manager
        .setBrowserHistoryForTesting(browserHistory ?? _TestBrowserHistory());
    final navigatorKey = GlobalKey<NavigatorState>();
    final home = descriptor('Home', inputs: homeInputs);
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: <NavigatorObserver>[
        if (trackScreens) ScreenTrackingNavigatorObserver(),
        manager.observer,
      ],
      onGenerateInitialRoutes: (_) => <Route<dynamic>>[routeFor(home)],
      onGenerateRoute: (_) => null,
    ));
    await tester.pump();
    return navigatorKey;
  }

  testWidgets('reconciles a partial prefix and removes obsolete routes',
      (tester) async {
    final navigatorKey = await pumpApp(tester);
    final settings = descriptor('Settings');
    final account = descriptor('Account');
    final profile = descriptor('Profile');
    final profileRoute = routeFor(profile);

    navigatorKey.currentState!.push(routeFor(settings));
    navigatorKey.currentState!.push(routeFor(account));
    navigatorKey.currentState!.push(profileRoute);
    await tester.pumpAndSettle();

    final destinationRoute = await manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home'), settings],
      destination: descriptor('System'),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );
    await tester.pumpAndSettle();

    expect(manager.history.map((entry) => entry.descriptor.identifier),
        <String>['Home', 'Settings', 'System']);
    expect(manager.exitReasonFor(profileRoute),
        EnsembleRouteExitReason.historyReconciled);

    navigatorKey.currentState!.pop('back-payload');
    await tester.pumpAndSettle();
    expect(await destinationRoute.popped, 'back-payload');
    expect(
        manager.exitReasonFor(destinationRoute), EnsembleRouteExitReason.back);
    expect(find.text('Settings'), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('empty history makes destination the new root', (tester) async {
    final navigatorKey = await pumpApp(tester);

    await manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[],
      destination: descriptor('Login'),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );
    await tester.pumpAndSettle();

    expect(manager.history.single.descriptor.identifier, 'Login');
    expect(navigatorKey.currentState!.canPop(), isFalse);
  });

  testWidgets('retained route preserves widget state', (tester) async {
    final navigatorKey = await pumpApp(tester);
    final settings = descriptor('Settings');
    navigatorKey.currentState!
        .push(routeFor(settings, child: const _RetainedCounter()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    await manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home'), settings],
      destination: descriptor('System'),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );
    await tester.pumpAndSettle();
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('1'), findsOneWidget);
  });

  testWidgets(
      'missing history stays lazy until it is revealed by navigation back',
      (tester) async {
    final navigatorKey = await pumpApp(tester);
    Animation<double>? outgoingSecondaryAnimation;
    final overview = descriptor('Overview');
    final overviewRoute = PageRouteBuilder<dynamic>(
      settings: EnsembleRouteSettings(
        descriptor: overview,
        payload: overview.toPayload(),
      ),
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
      pageBuilder: (_, __, ___) => const Scaffold(body: Text('Overview')),
      transitionsBuilder: (_, __, secondaryAnimation, child) {
        outgoingSecondaryAnimation = secondaryAnimation;
        return child;
      },
    );
    navigatorKey.currentState!.push(overviewRoute);
    await tester.pumpAndSettle();

    final constructed = <String>[];
    final factory = EnsembleRouteFactory((entry) {
      constructed.add(entry.identifier);
      return Scaffold(body: Text(entry.identifier));
    });

    await manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[
        descriptor('Home'),
        descriptor('Wifi'),
      ],
      destination: descriptor('SetRoomName'),
      createRoute: (entry, {required animate}) => factory.create(
        navigatorKey.currentContext!,
        entry,
        transition: const <String, dynamic>{'duration': 100},
        animate: animate,
      ),
    );

    expect(constructed, <String>['SetRoomName']);
    expect(overviewRoute.isActive, isTrue,
        reason:
            'the outgoing route must cover the lazy entry during animation');
    await tester.pump();
    expect(outgoingSecondaryAnimation?.value, 0,
        reason: 'lazy history must not animate the outgoing screen away');
    await tester.pumpAndSettle();
    expect(constructed, <String>['SetRoomName']);
    expect(overviewRoute.isActive, isFalse);

    navigatorKey.currentState!.pop();
    await tester.pump();

    expect(constructed, <String>['SetRoomName', 'Wifi']);
    await tester.pumpAndSettle();
    expect(find.text('Wifi'), findsOneWidget);
  });

  testWidgets('screen tracker ignores lazy history until Back reveals it',
      (tester) async {
    final navigatorKey = await pumpApp(tester, trackScreens: true);
    navigatorKey.currentState!.push(routeFor(descriptor('Overview')));
    await tester.pumpAndSettle();

    final factory = EnsembleRouteFactory((entry) {
      if (entry.identifier == 'Wifi') {
        ScreenTracker().trackScreenFromPayload(entry.toPayload());
      }
      return Scaffold(body: Text(entry.identifier));
    });

    await manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[
        descriptor('Home'),
        descriptor('Wifi'),
      ],
      destination: descriptor('SetRoomName'),
      createRoute: (entry, {required animate}) => factory.create(
        navigatorKey.currentContext!,
        entry,
        transition: const <String, dynamic>{'duration': 100},
        animate: animate,
      ),
    );
    await tester.pumpAndSettle();

    expect(ScreenTracker().getCurrentScreenIdentifier(), 'SetRoomName');
    expect(
      ScreenTracker().screenHistory.map((screen) => screen.screenName),
      <String?>['Home', 'SetRoomName'],
    );

    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(ScreenTracker().getCurrentScreenIdentifier(), 'Wifi');
    expect(
      ScreenTracker().screenHistory.map((screen) => screen.screenName),
      <String?>['Home', 'Wifi'],
    );
  });

  testWidgets('coalesces identical transactions while one is pending',
      (tester) async {
    final navigatorKey = await pumpApp(tester);
    final home = descriptor('Home');
    final system = descriptor('System');

    final first = manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[home],
      destination: system,
      createRoute: (entry, {required animate}) => routeFor(entry),
    );
    final second = manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[home],
      destination: system,
      createRoute: (entry, {required animate}) => routeFor(entry),
    );

    expect(identical(first, second), isTrue);
    await first;
    await tester.pumpAndSettle();
    expect(manager.history.map((entry) => entry.descriptor.identifier),
        <String>['Home', 'System']);
  });

  testWidgets('coalesces equivalent inputs with different map insertion order',
      (tester) async {
    final navigatorKey = await pumpApp(tester);
    final firstInputs = <String, dynamic>{
      'filter': <String, dynamic>{'active': true, 'sort': 'name'},
      'page': 1,
    };
    final secondInputs = <String, dynamic>{
      'page': 1,
      'filter': <String, dynamic>{'sort': 'name', 'active': true},
    };

    final first = manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home')],
      destination: descriptor('System', inputs: firstInputs),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );
    final second = manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home')],
      destination: descriptor('System', inputs: secondInputs),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );

    expect(identical(first, second), isTrue);
    await first;
    await tester.pumpAndSettle();
  });

  testWidgets('removed destination does not block the transaction queue',
      (tester) async {
    final navigatorKey = await pumpApp(tester);
    final first = manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home')],
      destination: descriptor('First'),
      createRoute: (entry, {required animate}) => routeFor(
        entry,
        transitionDuration:
            animate ? const Duration(seconds: 10) : Duration.zero,
      ),
    );
    await tester.pump();
    final firstRoute = await first;

    navigatorKey.currentState!
        .pushReplacement(routeFor(descriptor('LegacyReplacement')));
    final second = manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home')],
      destination: descriptor('Second'),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );

    await tester.pump();
    await tester.pump();
    final secondRoute = await second;
    expect(firstRoute.isActive, isFalse);
    expect(secondRoute.isActive, isTrue);
    expect(manager.history.map((entry) => entry.descriptor.identifier),
        <String>['Home', 'Second']);
  });

  testWidgets('lazy route reports reveal only after reverse transition',
      (tester) async {
    final navigatorKey = await pumpApp(tester);
    var constructed = false;
    final lazyDescriptor = descriptor('History');
    final lazyRoute = LazyEnsemblePageRouteBuilder<dynamic>(
      screenBuilder: (_) {
        constructed = true;
        return const Scaffold(body: Text('History'));
      },
      settings: EnsembleRouteSettings(
        descriptor: lazyDescriptor,
        payload: lazyDescriptor.toPayload(),
      ),
    );
    navigatorKey.currentState!.push(lazyRoute);
    final destination = routeFor(
      descriptor('Destination'),
      transitionDuration: const Duration(milliseconds: 200),
    );
    navigatorKey.currentState!.push(destination);
    await tester.pumpAndSettle();

    var revealed = false;
    lazyRoute.revealed.then((_) => revealed = true);
    navigatorKey.currentState!.pop();
    await tester.pump();

    expect(constructed, isTrue);
    expect(revealed, isFalse);
    await tester.pump(const Duration(milliseconds: 100));
    expect(revealed, isFalse);
    await tester.pumpAndSettle();
    expect(revealed, isTrue);
  });

  testWidgets('publishes a single reconciled snapshot to browser history',
      (tester) async {
    final browserHistory = _RecordingBrowserHistory();
    final navigatorKey = await pumpApp(
      tester,
      browserHistory: browserHistory,
    );

    await manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home')],
      destination: descriptor('System'),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );
    await tester.pumpAndSettle();

    expect(browserHistory.reconciliations, hasLength(1));
    expect(browserHistory.reconciliations.single.currentDepth, 1);
    expect(browserHistory.reconciliations.single.prefixLength, 1);
    expect(
      browserHistory.reconciliations.single.finalHistory
          .map((entry) => entry.identifier),
      <String>['Home', 'System'],
    );
  });

  testWidgets('browser snapshot preserves inputs of a wildcard-retained route',
      (tester) async {
    final browserHistory = _RecordingBrowserHistory();
    final navigatorKey = await pumpApp(
      tester,
      browserHistory: browserHistory,
      homeInputs: <String, dynamic>{'userId': 42},
    );

    await manager.navigateWithHistory(
      navigator: navigatorKey.currentState!,
      history: <EnsembleRouteDescriptor>[descriptor('Home')],
      destination: descriptor('System'),
      createRoute: (entry, {required animate}) => routeFor(entry),
    );
    await tester.pumpAndSettle();

    expect(
      browserHistory.reconciliations.single.finalHistory.first.inputs,
      <String, dynamic>{'userId': 42},
    );
  });
}

class _TestBrowserHistory implements NavigationBrowserHistory {
  @override
  bool get isHandlingPopState => false;

  @override
  void recordPop() {}

  @override
  void recordPush(List<EnsembleRouteDescriptor> snapshot) {}

  @override
  Future<void> reconcile({
    required int currentDepth,
    required int prefixLength,
    required List<EnsembleRouteDescriptor> finalHistory,
  }) async {}

  @override
  void replaceInitial(List<EnsembleRouteDescriptor> snapshot) {}
}

class _RecordingBrowserHistory extends _TestBrowserHistory {
  final List<_RecordedReconciliation> reconciliations = [];

  @override
  Future<void> reconcile({
    required int currentDepth,
    required int prefixLength,
    required List<EnsembleRouteDescriptor> finalHistory,
  }) async {
    reconciliations.add(_RecordedReconciliation(
      currentDepth,
      prefixLength,
      finalHistory,
    ));
  }
}

class _RecordedReconciliation {
  const _RecordedReconciliation(
      this.currentDepth, this.prefixLength, this.finalHistory);

  final int currentDepth;
  final int prefixLength;
  final List<EnsembleRouteDescriptor> finalHistory;
}

class _RetainedCounter extends StatefulWidget {
  const _RetainedCounter();

  @override
  State<_RetainedCounter> createState() => _RetainedCounterState();
}

class _RetainedCounterState extends State<_RetainedCounter> {
  var count = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => setState(() => count++),
          child: Text('$count'),
        ),
      );
}
