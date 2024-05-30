import 'package:ensemble/ensemble.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// demonstrating Ensemble integration with your existing Flutter App
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // (optional) pre-initialize asynchronously so Ensemble is ready
  // when your app switches to Ensemble screens. Add `await` before
  // this statement if your first page is an Ensemble's page.
  Ensemble().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MyHomePage(title: 'My Existing Flutter App'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
        ),
        body: Center(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This page is written in Flutter'),
            const SizedBox(height: 20),
            ElevatedButton(
              child: const Text("Now load an Ensemble page"),
              onPressed: () => loadEnsemblePage(context),
            )
          ],
        )));
  }

  void loadEnsemblePage(BuildContext context) {
    // Navigating to the home page of the configured App
    Ensemble().navigateApp(context);

    // navigate to a specific screen using ID or name
    //Ensemble().navigateApp(context, screenName: 'Goodbye');
  }
}
