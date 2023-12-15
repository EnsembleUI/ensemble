

import 'dart:collection';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';

class API {
  String name,uri;
  Map<String,String>? params;
  String method = 'get';
  API(this.name,this.uri,this.params);
  Future<http.Response> call(Map<String,String>? paramValues) async {
    Map<String,String> m = HashMap();
    if ( params != null ) {
      m.addAll(params!);
    }
    if ( paramValues != null ) {
      m.addAll(paramValues);
    }
    http.Response res;
    if ( method == 'get' ) {
      Uri _uri = Uri.parse(uri);

      //res = await http.get(Uri.dataFromString(uri, parameters: m));
      res = await http.get(_uri.replace(queryParameters:m));
    } else if ( method == 'post' ) {
      res = await http.post(Uri.dataFromString(uri, parameters: m));
    } else {
      throw Exception(method+' Method for http is not supported');
    }
    return res;
  }
  static API from(String name,YamlMap map) {
    String uri = map['uri'];
    Map<String,String>? params = HashMap();
    if ( map.containsKey('parameters') ) {
      map['parameters'].forEach((k,v){
        params[k.toString()] = v.toString();
      });
    }
    return API(name,uri,params);
  }
}
class APIs {
  static Map<String,API> from(YamlMap map) {
    Map<String,API> apis = HashMap();
    map.forEach((k,v) {
      apis[k] = API.from(k,v);
    });
    return apis;
  }
}