import 'package:flutter/material.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/page_model.dart';

class EnsembleTab extends StatefulWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const EnsembleTab({super.key, required this.navigatorKey});

  @override
  State<EnsembleTab> createState() => _EnsembleTabState();
}

class _EnsembleTabState extends State<EnsembleTab> {
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
        title: const Text('Ensemble Tab'),
      ),
      body: Column(
        children: [
          // Ensemble App - simulating KPN's main Ensemble integration
          Expanded(
            child: EnsembleApp(
              navigatorKey: widget.navigatorKey,
              screenScroller: _scrollController,
              screenPayload: ScreenPayload(
                screenName: 'Hello Home',
              ),
            ),
          ),
        ],
      ),
    );
  }
}