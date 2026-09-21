import 'package:ensemble/ensemble.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/apiproviders/api_provider.dart';
import 'package:ensemble/framework/widget/screen.dart' as ensemble;
import 'package:ensemble/page_model.dart';
import 'package:flutter/material.dart';

/// Initializes Ensemble after the Flutter shell is reached, then hosts the
/// Flutter bottom-nav app as `EnsembleApp(child:)`.
///
/// This matches the KPN PCA pattern: login stays a Flutter `MaterialApp`,
/// and Ensemble starts when the screen with the navbar and shop card appears.
class EnsembleHost extends StatefulWidget {
  const EnsembleHost({super.key, required this.child});

  final Widget child;

  @override
  State<EnsembleHost> createState() => _EnsembleHostState();
}

class _EnsembleHostState extends State<EnsembleHost> {
  EnsembleApp? _ensembleApp;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Ensemble().initialize();
      if (!mounted) return;
      // Do not pass `ensembleConfig:` — EnsembleApp.initApp() would call
      // initializeAPIProviders again and replace the test HTTP overlay.
      setState(() {
        _ensembleApp = EnsembleApp(child: widget.child);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Ensemble failed to initialize: $error',
              key: const ValueKey('ensemble_init_error'),
            ),
          ),
        ),
      );
    }
    final app = _ensembleApp;
    if (app == null) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              key: ValueKey('ensemble_loading'),
            ),
          ),
        ),
      );
    }
    return app;
  }
}

/// Named Ensemble screen rendered inside the Flutter host navigator.
class EnsembleShopView extends StatelessWidget {
  const EnsembleShopView({super.key});

  static const screenName = 'Shop';

  @override
  Widget build(BuildContext context) {
    final config = Ensemble().getConfig();
    if (config == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('ensemble_loading')),
      );
    }
    return ensemble.Screen(
      appProvider: AppProvider(
        definitionProvider: config.definitionProvider,
      ),
      screenPayload: ScreenPayload(screenName: screenName),
      apiProviders: APIProviders.clone(config.apiProviders ?? {}),
    );
  }
}

/// Host-pushed route that embeds the same Ensemble shop screen as the tab.
class ShopRoutePage extends StatelessWidget {
  const ShopRoutePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('shop_route_page'),
      appBar: AppBar(
        title: const Text('Shop'),
        leading: IconButton(
          key: const ValueKey('shop_back_button'),
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const EnsembleShopView(),
    );
  }
}
