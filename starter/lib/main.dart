import 'dart:async';
import 'dart:ui';

import 'package:ensemble/ensemble_app.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/error_screen.dart';
import 'package:ensemble_starter/generated/ensemble_modules.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// this demonstrates an App running exclusively with Ensemble
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initErrorHandler();
  await EnsembleModules().init();

  runApp(const MyApp());
}

/// The root widget that listens for connectivity changes and displays
/// either your main app (when online) or a "No Internet" screen (when offline).
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool hasInternet = false;
  late StreamSubscription connectivitySubscription;

  @override
  void initState() {
    super.initState();

    // Perform an initial connectivity check.
    _checkInternet().then((value) {
      setState(() {
        hasInternet = value;
      });
    });

    // Listen for connectivity changes.
    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) async {
      bool internet = await _checkInternet();
      if (internet != hasInternet) {
        setState(() {
          hasInternet = internet;
        });
      }
    });
  }

  @override
  void dispose() {
    connectivitySubscription.cancel();
    super.dispose();
  }

  /// Checks if the device is connected to the internet.
  Future<bool> _checkInternet() async {
    final dynamic result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  }

  @override
  Widget build(BuildContext context) {
    if (hasInternet) {
      // When online, display Ensemble App
      return EnsembleApp();
    } else {
      // Otherwise, show a static "No Internet" screen.
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off, size: 100, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'No Internet Connection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text('Please enable internet connectivity.'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    bool internet = await _checkInternet();
                    setState(() {
                      hasInternet = internet;
                    });
                  },
                  child: const Text("Retry"),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}

/// Initializes custom error handling.
void initErrorHandler() {
  ErrorWidget.builder = (FlutterErrorDetails errorDetails) {
    return ErrorScreen(errorDetails);
  };

  FlutterError.onError = (details) {
    if (details.exception is EnsembleError) {
      debugPrint(details.exception.toString());
    } else {
      debugPrint(details.exception.toString());
    }
  };

  // Handle asynchronous errors.
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint("Async Error: " + error.toString());
    return true;
  };
}
