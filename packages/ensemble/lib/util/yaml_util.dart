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
        } else if (v is YamlList) {
          value = _yamlToList(v);
        } else {
          value = v;
        }
        map[k] = value;
      });
    }
    return map;
  }

  static List<dynamic> _yamlToList(YamlList yamlList) {
    List<dynamic> list = [];
    for (var item in yamlList) {
      if (item is YamlMap) {
        list.add(yamlToMap(item));
      } else if (item is YamlList) {
        list.add(_yamlToList(item));
      } else {
        list.add(item);
      }
    }
    return list;
  }
}
