import 'package:yaml/yaml.dart';

class YamlUtil {

  // convert Yaml to Map
  static Map<String, dynamic> yamlToMap(YamlMap? yamlMap) {
    var map = <String, dynamic>{};
    if (yamlMap != null) {
      yamlMap.forEach((k, v) {
        dynamic value;
        if (v is YamlMap) {
          value = yamlToMap(v);
        } else {
          value = v;
        }
        map[k] = value;
      });
    }
    return map;
  }

}