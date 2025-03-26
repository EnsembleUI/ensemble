import 'package:flutter/material.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text('Home Tab', style: TextStyle(fontSize: 24)),
            SizedBox(height: 20),
            Text('Go to Sports tab to see Ensemble in action', 
                 style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}