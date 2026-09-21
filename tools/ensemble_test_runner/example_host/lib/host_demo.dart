import 'package:ensemble/ensemble.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/util/utils.dart';
import 'package:flutter/widgets.dart';

/// Dummy host console + HTTP traffic so the YAML report has App Logs / API Calls.
class HostDemoTraffic {
  static void log(String message) => debugPrint('host: $message');

  static Future<void> login(BuildContext context, {required String email}) {
    log('login API email=$email');
    return _invoke(
      context,
      name: 'hostLogin',
      url: 'https://jsonplaceholder.typicode.com/posts',
      method: 'POST',
      body: {'email': email, 'source': 'flutter-host'},
    );
  }

  static Future<void> session(BuildContext context) {
    log('session API');
    return _invoke(
      context,
      name: 'hostSession',
      url: 'https://jsonplaceholder.typicode.com/users/1',
    );
  }

  static Future<void> _invoke(
    BuildContext context, {
    required String name,
    required String url,
    String method = 'GET',
    Map<String, dynamic>? body,
  }) async {
    final provider = Ensemble().getConfig()?.apiProviders?['http'];
    if (provider == null) {
      log('skip $name (HTTP provider not ready)');
      return;
    }
    final api = Utils.getYamlMap({
      'url': url,
      'method': method,
      'authorization': 'none',
      if (body != null) 'body': body,
    });
    if (api == null) return;
    try {
      await provider.invokeApi(
        context,
        api,
        DataContext(buildContext: context),
        name,
      );
    } catch (error) {
      log('$name failed: $error');
    }
  }
}
