import 'package:ensemble/navigation/navigation_models.dart';
import 'package:ensemble/navigation/navigation_reconciler.dart';
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const reconciler = NavigationReconciler();

  ManagedEnsembleRoute managed(
    String? name, {
    String? screenId,
    Map<String, dynamic>? inputs,
    PageType pageType = PageType.regular,
  }) {
    final descriptor = EnsembleRouteDescriptor(
      screenId: screenId,
      screenName: name,
      inputs: inputs,
      pageType: pageType,
    );
    return ManagedEnsembleRoute(
      descriptor: descriptor,
      route: PageRouteBuilder<void>(
        settings: EnsembleRouteSettings(
          descriptor: descriptor,
          payload: descriptor.toPayload(),
        ),
        pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }

  EnsembleRouteDescriptor desired(String name,
          {Map<String, dynamic>? inputs}) =>
      EnsembleRouteDescriptor(screenName: name, inputs: inputs);

  test('retains the longest compatible prefix', () {
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[
        managed('Home'),
        managed('Settings'),
        managed('Account'),
        managed('Profile'),
      ],
      <EnsembleRouteDescriptor>[desired('Home'), desired('Settings')],
    );

    expect(result.prefixLength, 2);
    expect(result.retained.map((route) => route.descriptor.identifier),
        <String>['Home', 'Settings']);
    expect(result.obsolete.map((route) => route.descriptor.identifier),
        <String>['Account', 'Profile']);
    expect(result.missing, isEmpty);
  });

  test('stops matching when inputs differ deeply', () {
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[
        managed('Home'),
        managed('Product', inputs: <String, dynamic>{
          'product': <String, dynamic>{'id': 1}
        }),
      ],
      <EnsembleRouteDescriptor>[
        desired('Home'),
        desired('Product', inputs: <String, dynamic>{
          'product': <String, dynamic>{'id': 2}
        }),
      ],
    );

    expect(result.prefixLength, 1);
    expect(result.obsolete.single.descriptor.identifier, 'Product');
    expect(result.missing.single.identifier, 'Product');
  });

  test('omitted requested inputs retain the existing route and its inputs', () {
    final currentHome = managed('Home', inputs: <String, dynamic>{
      'userId': 42,
      'filters': <String, dynamic>{'active': true},
    });
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[currentHome],
      <EnsembleRouteDescriptor>[desired('Home')],
    );

    expect(result.prefixLength, 1);
    expect(result.retained.single, same(currentHome));
    expect(result.obsolete, isEmpty);
    expect(result.missing, isEmpty);
  });

  test('empty requested inputs retain a route with existing inputs', () {
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[
        managed('Home', inputs: <String, dynamic>{'userId': 42}),
      ],
      <EnsembleRouteDescriptor>[
        desired('Home', inputs: <String, dynamic>{}),
      ],
    );

    expect(result.prefixLength, 1);
  });

  test('supplied equal inputs retain the existing route', () {
    final inputs = <String, dynamic>{
      'user': <String, dynamic>{'id': 42},
    };
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[managed('Home', inputs: inputs)],
      <EnsembleRouteDescriptor>[desired('Home', inputs: inputs)],
    );

    expect(result.prefixLength, 1);
  });

  test('supports duplicate screens with different inputs', () {
    final current = <ManagedEnsembleRoute>[
      managed('Home'),
      managed('Product', inputs: <String, dynamic>{'id': 1}),
      managed('Product', inputs: <String, dynamic>{'id': 2}),
    ];
    final requested = <EnsembleRouteDescriptor>[
      desired('Home'),
      desired('Product', inputs: <String, dynamic>{'id': 1}),
      desired('Product', inputs: <String, dynamic>{'id': 2}),
    ];

    expect(reconciler.reconcile(current, requested).prefixLength, 3);
  });

  test('name request retains a route that also has a screen ID', () {
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[
        managed('Details', screenId: 'screen-123'),
      ],
      <EnsembleRouteDescriptor>[desired('Details')],
    );

    expect(result.prefixLength, 1);
  });

  test('ID-only route does not guess equivalence with a screen name', () {
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[
        managed(null, screenId: 'Details'),
      ],
      <EnsembleRouteDescriptor>[desired('Details')],
    );

    expect(result.prefixLength, 0);
  });

  test('regular request never retains a modal with the same name', () {
    final result = reconciler.reconcile(
      <ManagedEnsembleRoute>[
        managed('Details', pageType: PageType.modal),
      ],
      <EnsembleRouteDescriptor>[desired('Details')],
    );

    expect(result.prefixLength, 0);
  });

  test('handles empty and unrelated histories', () {
    expect(
      reconciler.reconcile(
        <ManagedEnsembleRoute>[managed('A')],
        <EnsembleRouteDescriptor>[],
      ).obsolete,
      hasLength(1),
    );
    expect(
      reconciler.reconcile(
        <ManagedEnsembleRoute>[managed('A')],
        <EnsembleRouteDescriptor>[desired('X'), desired('Y')],
      ).prefixLength,
      0,
    );
  });
}
