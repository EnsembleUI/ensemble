import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates a platform HttpClient without consulting Flutter's current
/// HttpOverrides. Widget-test bindings replace HttpClient requests with fake
/// responses, including inside callbacks dispatched through platform channels.
/// Runner-owned Firebase bridges need actual network traffic instead.
HttpClient createRealNetworkHttpClient([SecurityContext? context]) {
  final client = _RealNetworkHttpOverrides().createHttpClient(context);
  // Flutter's widget-test HTTP shim can install a per-process loopback proxy.
  // Runner-owned local services must bypass it and connect to their actual
  // listening port; public hosts still use the platform/environment proxy.
  client.findProxy = (uri) => _isLoopbackHost(uri.host)
      ? 'DIRECT'
      : HttpClient.findProxyFromEnvironment(uri);
  return client;
}

bool _isLoopbackHost(String host) {
  final normalized = host.toLowerCase();
  return normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized == '127.0.0.1' ||
      normalized == '::1' ||
      normalized == '[::1]';
}

/// Runs package:http convenience calls and dart:io calls with real clients.
///
/// The test binding installs an HttpOverrides in its zone, but package:http
/// convenience methods can use a zone-scoped Client instead of consulting
/// HttpOverrides. Installing both here keeps application and host callbacks
/// on the same real-network path.
Future<T> runWithRealNetworkHttpClient<T>(Future<T> Function() callback) {
  final client = IOClient(createRealNetworkHttpClient());
  // Flutter's test binding installs a global fake HttpOverrides that returns
  // HTTP 400 for every request. The zone override below covers work started in
  // this callback, but Flutter image streams can start their NetworkImage
  // request from a binding-owned async callback in the root zone. Temporarily
  // replace the binding override as well so those requests reach the network.
  // Restore it even when the test fails; the runner executes multiple attempts
  // in the same isolate.
  final previousGlobalOverride = HttpOverrides.current;
  HttpOverrides.global = _RealNetworkHttpOverrides();
  return HttpOverrides.runZoned(
    () async {
      try {
        return await http.runWithClient(callback, () => client);
      } finally {
        try {
          client.close();
        } finally {
          HttpOverrides.global = previousGlobalOverride;
        }
      }
    },
    createHttpClient: createRealNetworkHttpClient,
  );
}

class _RealNetworkHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context);
}
