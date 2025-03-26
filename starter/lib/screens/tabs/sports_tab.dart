import 'package:flutter/material.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/page_model.dart';
import '../../util/ensemble_manager.dart';

class SportsTab extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const SportsTab({super.key, required this.navigatorKey});

  @override
  State<SportsTab> createState() => _SportsTabState();
}

class _SportsTabState extends State<SportsTab> {
  final ScrollController _scrollController = ScrollController();
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sports'),
      ),
      body: EnsembleApp(
        // Using Utils.globalAppKey internally
        navigatorKey: widget.navigatorKey,
        screenScroller: _scrollController,
        // Register external methods to handle navigation
        externalMethods: EnsembleManager.instance.getExternalMethods(
          context, 
          widget.navigatorKey
        ),
        screenPayload: ScreenPayload(
          // This would be your Ensemble screen name
          screenName: 'Hello Home',
          arguments: {
            'title': 'Sports Data',
            'id': '12345',  // Sample media ID to pass to the external method
          },
        ),
      ),
    );
  }
}