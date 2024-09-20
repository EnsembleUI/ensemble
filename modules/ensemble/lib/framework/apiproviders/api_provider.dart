import 'package:ensemble/framework/apiproviders/firestore/firestore_api_provider.dart';
import 'package:ensemble/framework/apiproviders/http_api_provider.dart';
import 'package:ensemble/framework/data_context.dart';
import 'package:flutter/widgets.dart';
import 'package:yaml/yaml.dart';

abstract class APIProvider {
  Future<void> init(String appId, Map<String, dynamic> config);
  Future<Response> invokeApi(
      BuildContext context, YamlMap api, DataContext eContext, String apiName);
  Future<Response> invokeMockAPI(DataContext eContext, dynamic mock);
  APIProvider clone();
  dispose();
}

mixin LiveAPIProvider {
  Future<Response> subscribeToApi(BuildContext context, YamlMap api,
      DataContext eContext, String apiName, ResponseListener listener);
  Future<void> unSubscribeToApi(String apiName);
}

class APIProviders extends InheritedWidget {
  Map<String, APIProvider> providers;

  APIProviders({super.key, required Widget child, required this.providers})
      : super(child: child);
  APIProvider getProvider(String? provider) {
    if (provider == null) {
      return httpProvider;
    } else {
      return providers[provider] ?? httpProvider;
    }
  }

  static Map<String, APIProvider> clone(Map<String, APIProvider> providers) {
    Map<String, APIProvider> newProviders = {};
    providers.forEach((key, value) {
      newProviders[key] = value.clone();
    });
    return newProviders;
  }

  HTTPAPIProvider get httpProvider =>
      providers['http'] as HTTPAPIProvider? ?? HTTPAPIProvider();
  static APIProviders of(BuildContext context) {
    APIProviders? providers =
        context.dependOnInheritedWidgetOfExactType<APIProviders>();
    if (providers == null) {
      //just return http provider for now, this should not happen but we don't want to crash the app
      return APIProviders(
          providers: {'http': HTTPAPIProvider()}, child: Container());
    }
    return providers!;
  }

  static APIProvider? initProvider(String type) {
    switch (type) {
      case 'http':
        return HTTPAPIProvider();
      case 'firestore':
        return FirestoreAPIProvider();
      default:
        return null;
    }
  }

  @override
  bool updateShouldNotify(covariant APIProviders oldProviders) =>
      oldProviders.providers != providers;
}

abstract class Response {
  APIState apiState = APIState.idle;
  dynamic body;
  String apiName = '';
  bool _isOkay = true;
  bool get isOkay => _isOkay;
  set isOkay(bool value) {
    _isOkay = value;
  }

  Map<String, dynamic>? headers;
  int? statusCode;
  String? reasonPhrase;
  updateState({required apiState}) {
    this.apiState = apiState;
  }
}

typedef ResponseListener = void Function(Response response);

enum APIState { idle, loading, success, error }

extension APIStateX on APIState {
  bool get isLoading => this == APIState.loading;

  bool get isSuccess => this == APIState.success;

  bool get isError => this == APIState.error;
}
