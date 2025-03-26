import 'package:flutter/material.dart';
import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/page_model.dart';

/// This screen simulates KPN's content detail screen with a nested Ensemble app
class ContentDetailScreen extends StatefulWidget {
  final String mediaId;
  final GlobalKey<NavigatorState> navigatorKey;
  
  const ContentDetailScreen({
    super.key, 
    required this.mediaId,
    required this.navigatorKey,
  });

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
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
        title: Text('Content Detail: ${widget.mediaId}'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Content info section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Media Content',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text('ID: ${widget.mediaId}'),
                const SizedBox(height: 16),
                const Text('This screen contains another Ensemble app below:'),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // The issue occurs here - a nested Ensemble app inside another screen
          // that was opened from an Ensemble app
          Expanded(
            child: EnsembleApp(
              // Using the same navigator key here causes the issue
              navigatorKey: null,
              screenScroller: _scrollController,
              screenPayload: ScreenPayload(
                // This opens a different Ensemble screen
                screenName: 'Goodbye',
                arguments: {
                  'title': 'Nested Ensemble Screen',
                  'mediaId': widget.mediaId,
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}