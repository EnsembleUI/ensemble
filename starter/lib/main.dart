import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'util/ensemble_manager.dart';

void main() async {
  // Initialize Flutter binding first
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global navigator key that will be shared
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  // Initialize Ensemble after Flutter binding is initialized
  await EnsembleManager.instance.initialize();
  
  runApp(MyApp(navigatorKey: navigatorKey));
}

class MyApp extends StatelessWidget {
  final GlobalKey<NavigatorState> navigatorKey;
  
  const MyApp({super.key, required this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ensemble Issue Demo',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: HomeScreen(navigatorKey: navigatorKey),
    );
  }
}