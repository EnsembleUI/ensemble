import 'package:ensemble/framework/theme/theme_loader.dart';
import 'package:ensemble/layout/ensemble_page_route.dart';
import 'package:ensemble/navigation/navigation_models.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';

/// Builds an Ensemble screen when a route is ready to materialize it.
typedef EnsembleScreenFactory = Widget Function(
    EnsembleRouteDescriptor descriptor);

/// Canonical route-construction path shared by regular and stack navigation.
class EnsembleRouteFactory {
  const EnsembleRouteFactory(this.screenFactory);

  /// Screen builder shared by eager destinations and lazy history entries.
  final EnsembleScreenFactory screenFactory;

  /// Creates an eager animated destination or a dormant historical route.
  PageRouteBuilder<dynamic> create(
    BuildContext context,
    EnsembleRouteDescriptor descriptor, {
    Map<String, dynamic>? transition,
    bool animate = true,
  }) {
    final settings = EnsembleRouteSettings(
      descriptor: descriptor,
      payload: descriptor.toPayload(),
    );
    if (!animate) {
      // Historical entries need to exist in Navigator for native Back behavior,
      // but constructing their Ensemble screens here would run lifecycle work
      // for screens the user has not visited.
      return LazyEnsemblePageRouteBuilder<dynamic>(
        screenBuilder: (_) => screenFactory(descriptor),
        settings: settings,
      );
    }

    final defaults =
        Theme.of(context).extension<EnsembleThemeExtension>()?.transitions ??
            const <String, dynamic>{};
    final transitionType = PageTransitionTypeX.fromString(
        transition?['type'] ?? defaults['page']?['type']);
    final alignment = Utils.getAlignment(
        transition?['alignment'] ?? defaults['page']?['alignment']);
    final duration = Utils.getInt(
      transition?['duration'] ?? defaults['page']?['duration'],
      fallback: 250,
    );

    final screen = screenFactory(descriptor);

    return EnsemblePageRouteBuilder(
      child: screen,
      transitionType: transitionType ?? PageTransitionType.fade,
      alignment: alignment ?? Alignment.center,
      duration: Duration(milliseconds: duration),
      settings: settings,
    );
  }
}
