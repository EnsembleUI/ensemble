import 'package:ensemble/framework/data_context.dart';
import 'package:ensemble/util/yaml_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:yaml/yaml.dart';

void main() {
  Map<String, dynamic> dataMap = {
    'result': {
      'name': 'Peter Parker',
      'age': 25,
      'first_name': 'Peter',
      'last-name': 'Parker',
      'is_superhero': true,
    }
  };
  DataContext getBaseContext() {
    return DataContext(buildContext: MockBuildContext(), initialMap: dataMap);
  }

  YamlMap yamlPayload = YamlMap.wrap({
    'payload': {
      'name': '\${result.name}',
      'age': '\${age}',
      'superhero': '\${is_superhero}'
    }
  });

  test('Yaml to Map conversion', () {
    Map<String, dynamic> map = YamlUtil.yamlToMap(YamlMap.wrap({
      'output': {
        'name': 'peter',
        'skills': ['running', 'flying'],
        'age': 20,
        'superhero': true
      }
    }));
    expect(map['output']['name'], 'peter');
    expect(map['output']['skills'][0], 'running');
    expect(map['output']['skills'][1], 'flying');
    expect(map['output']['age'], 20);
    expect(map['output']['superhero'], true);
  });
}

class MockBuildContext extends Mock implements BuildContext {}
