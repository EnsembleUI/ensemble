import 'package:flutter/material.dart';
import 'package:smart_wifi_connect/smart_wifi_connect.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const WifiConnectDemo(),
    );
  }
}

class WifiConnectDemo extends StatefulWidget {
  const WifiConnectDemo({super.key});

  @override
  State<WifiConnectDemo> createState() => _WifiConnectDemoState();
}

class _WifiConnectDemoState extends State<WifiConnectDemo> {
  final _ssidController = TextEditingController();
  final _passwordController = TextEditingController();
  String _status = 'Not connected';

  Future<void> _connect() async {
    setState(() => _status = 'Connecting...');

    final result = await SmartWifiConnect.connect(
      ssid: _ssidController.text,
      password: _passwordController.text,
    );

    setState(() {
      _status = result.success
          ? 'Connected! (${result.status.name})'
          : 'Failed: ${result.status.name} - ${result.message}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wi-Fi Connect Demo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ssidController,
              decoration: const InputDecoration(labelText: 'SSID'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _connect,
              child: const Text('Connect'),
            ),
            const SizedBox(height: 16),
            Text(_status),
          ],
        ),
      ),
    );
  }
}
