import 'package:ensemble_ts_interpreter/invokables/context.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:json_path/json_path.dart';
import 'dart:convert';
import 'dart:io';
import 'package:test/test.dart';
import 'package:jsparser/jsparser.dart';
class Ensemble extends Object with Invokable {
  String? name,date,firstName,lastName,text;
  String? navigateScreenCalledForScreen;
  Ensemble(this.name);
  @override
  Map<String, Function> getters() {
    return {
      'date': () => date,
      'firstName':() => firstName,
      'lastName':() => lastName,
      'name':() => name,
      'text':() => text
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'navigateScreen': (screenName) => navigateScreenCalledForScreen = screenName,
      'setNames': (firstName,lastName) { this.firstName = firstName; this.lastName = lastName;},
      'setDate': (date) => this.date = date,
      'setNamesAndDate': (firstName,lastName,date) {methods()['setNames']!(firstName,lastName);methods()['setDate']!(date);},
      'getDate': () => date,
      'invokeAPI': (String apiName, [dynamic value]) {
        if (value is Map) {
          Map<String, dynamic> results = {};
          value.forEach((key, value) {
            results[key.toString()] = value;
            print('api:$apiName, input:[${key.toString()}, $value]');
          });
        }
      }
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'text': (v) => text = v
    };
  }

}

class ThisObject with Invokable {
  String _identity = 'Spiderman';
  @override
  Map<String, Function> getters() {
    return {
      'identity': () => _identity
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'toString': () => 'ThisObject'
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'identity': (newValue) => _identity = newValue
    };
  }

}
void main() {
  //ensembleStore.session.login.contextId = response.body.data.contextID;
  Map<String, dynamic> initContext() {
    return {
      'response': {
        'name': 'Peter Parker',
        'age': 25,
        'first_name': 'Peter',
        'last-name': 'Parker',
        'body': {
          'data': {
            'contextID': '123456'
          }
        },
        'headers': {
          'Set-Cookie':'abc:xyz;mynewcookie:abc'
        }
      },
      'ensembleStore': {
        'session': {
          'login': {
          }
        }
      },
      'ensemble':Ensemble('EnsembleObject'),
      'users':[{'name':'John'},{'name':'Mary'}],
      'this': ThisObject(),
      'age':3,
      'apiChart':{'data':[]},
      'getStringValue': (dynamic value) {
        String? val = value?.toString();
        if ( val != null && val.startsWith('r@') ) {
          return 'Translated $val';
        }
        return val;
      },
    };
  }
  test('MapTest', () async {
    /*
    ensembleStore.session.login.contextId = response.body.data.contextID;
    ensemble.navigateScreen("KPN Home");
     */
    String codeToEvaluate = """
      ensembleStore.session.login.contextId = response.body.data.contextID;
      ensemble.navigateScreen("KPN Home");
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['ensembleStore']['session']['login']['contextId'],'123456');
    expect((context['ensemble'] as Ensemble).navigateScreenCalledForScreen,'KPN Home');
  });
  test('expressionTest', () async {
    String codeToEvaluate = """
      ensemble.name
      """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(rtnValue,(context['ensemble'] as Ensemble).name);
  });
  test('propsThroughQuotesTest', () async {
    String codeToEvaluate = """
      var a = 0;
      ensembleStore.session.login.cookie = response.headers['Set-Cookie'].split(';')[a]
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['ensembleStore']['session']['login']['cookie'],context['response']['headers']['Set-Cookie'].split(';')[0]);
  });
  test('arrayAccessTest', () async {
    String codeToEvaluate = """
      users[0] = users[users.length-1];
      users[0];
      """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(rtnValue,context['users'][1]);
  });
  test('mapTest', () async {
    String codeToEvaluate = """
      var newUsers = users.map(function (user,index) {
        user.name += "NEW" + index;
        return user;
      });
      """;
    Map<String, dynamic> context = initContext();
    String origValue = context['users'][1]['name'];
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['newUsers'][1]['name'], origValue + 'NEW1');
  });
  test('variableDeclarationTest', () async {
    String codeToEvaluate = """
      var user = 'John Doe';
      user += ' II';
      var age;
      age = 12;
      age += 3;
      var curr = 12.9382929;
      curr= curr.prettyCurrency();
      var str = 'user='+user+' is '+age+' years old and has '+curr;
      users[0]['name'] = str;
      """;
    Map<String, dynamic> context = initContext();
    context.remove('age');
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['users'][0]['name'],'user=John Doe II is 15 years old and has \$12.94');
  });
  test('primitives', () async {
    String codeToEvaluate = """
    var curr = '12.3456';
    curr = curr.tryParseDouble().prettyCurrency();
    users[0]['name'] = 'John has '+curr;
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['users'][0]['name'],'John has \$12.35');
  });
  test('returnExpression', () async {
    String codeToEvaluate = """
       'quick brown fox '+users[0]["name"]+' over the fence and received '+users[0]["name"].length+' dollars'
      """;
    Map<String, dynamic> context = initContext();
    context['users'][0]["name"] = 'jumped';
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(rtnValue,'quick brown fox jumped over the fence and received 6 dollars');
  });
  test('returnIdentifier', () async {
    Map<String, dynamic> context = initContext();
    dynamic rtn = JSInterpreter.fromCode("""age""",SimpleContext(context)).evaluate();
    expect(rtn,context['age']);
  });
  test('ifstatement', () async {
    String codeToEvaluate = """
      if ( age == 3 ) {
      }
      if ( age == 2 ) {
        users[0]['age'] = 'Two years old';
      } else {
        users[0]['age'] = 'Over Two years old';
      }
      """;
    Map<String, dynamic> context = initContext();
    context['age'] = 3;
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['users'][0]['age'],'Over Two years old');
  });
  test('ternary', () async {
    String codeToEvaluate = """
          (age > 2)?users[0]['age']='More than two years old':users[0]['age']='2 and under';
      """;
    Map<String, dynamic> context = initContext();
    context['age'] = 1;
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['users'][0]['age'],'2 and under');
  });
  test('moreArrayTests', () async {
    String codeToEvaluate = """
      var a = {};
      apiChart.data = [{
          "color": "0xffffcccb",
          "data": [-97,-33,-57,-56]
        }];
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['apiChart']['data'][0]['data'][1],-33);
  });
  test('jsonpathtest', () async {
    /*
      see jsonpath.json. This is not a ast test
     */
    final file = File('test_resources/jsonpath.json');
    final json = jsonDecode(await file.readAsString());
    List years = JsonPath(r'$..Year').read(json).map((match)=>int.parse(match.value as String)).toList();
    List pop = JsonPath(r'$..Population').read(json).map((match)=>match.value).toList();
    expect(years[3],1930);
    expect(pop[3],6.93);
  });
  test('jsonpathintstest', () async {
    final file = File('test_resources/jsonpath.json');
    final json = jsonDecode(await file.readAsString());
    Map<String, dynamic> context = initContext();
    context['response'] = json;
    JSInterpreter.fromCode("""
      var result = response.path('\$..Year',function (match) {match});
      """,SimpleContext(context)).evaluate();
    expect(context['result'][1],'1910');
  });
  test('listsortuniquetest', () async {
    String codeToEvaluate = """
      var list = [10,4,2,4,1,3,8,4,5,6,2,4,8,7,2,9,9,1];
      var uniqueList = list.unique();
      var sortedList = uniqueList.sort();
      var strList = ["2","4","4","1","3"];
      strList = strList.unique().sort(function (a,b) {
        var intA = a.tryParseInt();
        var intB = b.tryParseInt();
        if ( intA < intB ) {
          return -1;
        } else if ( intA > intB ) {
          return 1;
        }
        return 0;
      });
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['sortedList'][2],3);
    expect(context['strList'][2],"3");
  });
  test('getstringvaluetest', () async {
    String codeToEvaluate = """
      var stringToBeTranslated = 'r@kpn.signin';
      ensemble.navigateScreen('r@navigateScreen');
      response.name = response.name;
      users[0]['name'] = 'r@John';
      users[1]['name'] = 'Untranslated Mary';
      """;

    Map<String, dynamic> context = initContext();
    String origStr = 'r@kpn.signin';
    context['response']['name'] = 'r@Peter Parker';
    context['users'][0]['name'] = 'r@John';
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['stringToBeTranslated'],'Translated $origStr');
    expect(context['response']['name'],'r@Peter Parker');
    expect(context['users'][0]['name'],'Translated r@John');
    expect(context['users'][1]['name'],'Untranslated Mary');
  });
  test('es121', () async {
    String codeToEvaluate = """
      getPrivWiFi.body.status.wlanvap.vap5g0priv.VAPStatus == 'Up' ? true : false
      """;
    Map<String, dynamic> context = initContext();
    Map getPrivWiFi = {
      'body': {
        'status': {
          'wlanvap': {
            'vap5g0priv': {
              'VAPStatus': 'down'
            }
          }
        }
      }
    };
    context['getPrivWiFi'] = getPrivWiFi;
    dynamic rtn = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(rtn,false);
  });
  test('jsparser', () async {
    String codeToEvaluate = """
      var arr = ['worked!'];
      users.map(function(user) {
        arr.push(' ');
        arr.push('hello '+user.name);
      });
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['arr'][0],'worked!');
  });
  test('nullTest', () async {
    String codeToEvaluate = """
      if ( ensemble['test'] == null ) {
        return 'it worked!';
      } else {
        return 'sad face';
       }
      """;
    Map<String, dynamic> context = initContext();

    dynamic rtn = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(rtn,'it worked!');
  });
  test('notNullTest', () async {
    String codeToEvaluate = """
      if ( ensemble.name == null ) {
        return 'sad face!';
      } else {
        return 'it worked!';
       }
      """;
    Map<String, dynamic> context = initContext();
    dynamic rtn = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(rtn,'it worked!');
  });
  test('bindingconditionaltests', () async {
    String codeToEvaluate = """
      myText.text.toLowerCase();
      ( myText.text == 'hello' ) ? 'Hey' : 'nope';
      ( myWidgets.collection.widgets.text == myAPI.response.body.text ) ? myWidget.text : myDD.value;
      ( myWidgets.collection.widgets.text == '1' ) ? myWidget.text : myDD.value;
      myText.value != 'hello' 
      myWidgets.collection.widgets.text != myAPI.response.body['text'] 
      myWidgets.collection.widgets.text != myAPI.response.body[1];
      abc.text = myWidgets.widget.text;
      ensemble.storage.merchants[name];
      """;
    Program ast = JSInterpreter.parseCode(codeToEvaluate);
    List<String> bindings = Bindings().resolve(ast);
    expect(bindings.length,12);
    expect(bindings[0],'myText.text');
    expect(bindings[1],'myWidgets.collection.widgets.text');
    expect(bindings[2],'myAPI.response.body.text');
    expect(bindings[3],'myWidgets.collection.widgets.text');
    expect(bindings[4],'myText.value');
    expect(bindings[5],'myWidgets.collection.widgets.text');
    expect(bindings[6],"myAPI.response.body['text']");
    expect(bindings[7],"myWidgets.collection.widgets.text");
    expect(bindings[8],"myAPI.response.body[1]");
    expect(bindings[9],"myWidgets.widget.text");
    expect(bindings[10],"ensemble.storage.merchants");
    expect(bindings[11],"name");
  });
  test('bindingdirecttests', () async {
    String codeToEvaluate = """
      myWidgets;
      myAPI.response;
      myAPI.response.body.text;

      """;
    Program ast = parsejs(codeToEvaluate);
    List<String> bindings = Bindings().resolve(ast);
    expect(bindings.length,3);
    expect(bindings[0],'myWidgets');
    expect(bindings[1],'myAPI.response');
    expect(bindings[2],'myAPI.response.body.text');
  });
  test('bindingfunctionargumenttests', () async {
    String codeToEvaluate = """
      utils.translate(myText.text);
      utils.translate(myText.getProperty(allProperties.textProps.property(widget.text)));
      abc.text = utils.translate(myText.getProperty(allProperties.textProps.property(widget.text2)));
      utils.translate(myText.text('myText'));
      utils.translate('myText');
      abc.text = utils.translate(myText.getProperty(allProperties.textProps.property('text')));
      abc.text = utils.translate(myText.getProperty(allProperties.textProps.property('text'+myWidget.text)));
      var abc = myAPI.body.status;
      """;
    Program ast = parsejs(codeToEvaluate);
    List<String> bindings = Bindings().resolve(ast);
    expect(bindings.length,5);
    expect(bindings[0],'myText.text');
    expect(bindings[1],'widget.text');
    expect(bindings[2],'widget.text2');
    expect(bindings[3],'myWidget.text');
    expect(bindings[4],'abc');
  });

  test('andorexpressionstest', () async {
    String codeToEvaluate = """
        var date = null || '2022-08-08'
        date += ':00:00';
        var _false = 123 == 234 && null;
        var _date = abcdef || date;
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['date'],'2022-08-08:00:00');
    expect(context['_false'],false);
    expect(context['_date'],context['date']);
  });
  test('binaryoperatortest', () async {
    String codeToEvaluate = """
       var a = 20;
       var b = 10;
       return (a/b)*50 + 100 - 100;
       """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(rtnValue,100);
  });
  test('forinoperatortest', () async {
    String codeToEvaluate = """
      var indices = [];
      for (var i = 0; i < 5; i++) {
        console.log('Outer For loop count: ' + i);
        for (var j = 0; j < 5; j++) {
            console.log('   Inner For loop count: ' + j);
            if (j === 2) {
                indices.push(i);
                console.log('   Inner For loop break at 2');
                break;
            }
        }
      }
      console.log(indices);
    """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['indices'][2],2);
  });

  test('whilelooptest', () async {
    String codeToEvaluate = """
      var indices = [];
      var i =0;
      var j = 0;
      while (i < 5) {
        console.log('Outer For loop count: ' + i);
        while (j < 5) {
            console.log('   Inner For loop count: ' + j);
            if (j === 2) {
                indices.push(i);
                console.log('   Inner For loop break at 2');
                break;
            }
            j++;
        }
        i++;
      }
      console.log(indices);
    """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['indices'][2],2);
  });

  test('dowhiletest', () async {
    String codeToEvaluate = """
      var indices = [];
      var i =0;
      var j = 0;
      do {
        console.log('Outer For loop count: ' + i);
        do {
            console.log('   Inner For loop count: ' + j);
            if (j === 2) {
                indices.push(i);
                console.log('   Inner For loop break at 2');
                break;
            }
            j++;
        } while (j < 5);
        i++;
      } while (i < 5);
      console.log(indices);
    """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['indices'][2],2);
  });

  test('forinoperatortest', () async {
    String codeToEvaluate = """
      var i =0;
      var p = 'Khurram'; 
      for ( var person in people ) {    
        people[person]['last_name'] += people[person]['first_name'];
        console.log(people[person].first_name);
        if ( i == 1 ) {
          p = person;
          break;
        }
        i++;
      }
      return p;
       """;
    Map<String, dynamic> context = initContext();
    context['people'] = {
      'p1': {'first_name':'jon','last_name':'adams'},
      'p2': {'first_name':'jane','last_name':'doe'},
      'p3': {'first_name':'mick','last_name':'jagger'},
    };
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['people']['p1']['last_name'],'adamsjon');
    expect(context['people']['p2']['last_name'],'doejane');
    expect(context['people']['p3']['last_name'],'jagger');
    expect(rtnValue,'p2');
  });

  test('regextest', () async {
    String strExp = r'(\w+)';
    RegExp exp = RegExp('$strExp');
    String str = 'Parse my string';
    Iterable<RegExpMatch> matches = exp.allMatches(str);
    for (final m in matches) {
      print(m[0]);
    }
    String blah = "'\d+'";
    strExp = r''+blah;
    bool a = RegExp(blah).hasMatch("'123'");
    print('matched='+a.toString());
    var email = r'(\w)\1{2,}';
    exp = RegExp('$email');
    bool hasMatch = exp.hasMatch('1233344');
    print('hasMatch=$hasMatch');
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(r'var a = /\d+/;a = a.test("123");',SimpleContext(context)).evaluate();
    expect(context['a'],true);
  });
  test('mathtest', () async {
    String codeToEvaluate = """
      var a = Math.floor(5.85);
      var b = parseDouble("1.543");
      var c = parseInt('F0',16);
      var d = parseFloat("12.3456");
      var e = Math.pow(2,2);
      var f = Math.trunc(Math.log(5));
      var g = 5.7767.toFixed(2);
      var i = parseInt('300');
      var j = i.toString(16);
      var k = i.toString();
       """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['a'],5);
    expect(context['b'],1.543);
    expect(context['c'],240);
    expect(context['d'],12.3456);
    expect(context['e'],4);
    expect(context['f'],1);
    expect(context['g'],'5.78');
    expect(context['i'],300);
    expect(context['j'],'12c');
    expect(context['k'],'300');
  });
  //function tests
  test('variableDeclarationWithArrayTest', () async {
    String codeToEvaluate = """
      var arr = [];
      arr[0] = 'hello';
      arr[1] = ' ';
      arr.add('nobody');
      users.map(function(user) {
        arr.add(' ');
        arr.add('hello '+user.name);
      });
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect((context['arr']).join(''),'hello nobody hello John hello Mary');
  });
  test('functiondeclarationtext', () async {
    String codeToEvaluate = """
      var i = 0;
      var users = [{'name':'Khurram'},{'name':'Mahmood'}];
      updateSalary(users,noArgFunction());
      return manyParms(users[0],noArgFunction()[0],'Hello','How','are','you','today,');
      function noArgFunction() {
        var salaries = [10000,200000];
        salaries[1] = 900000;
        return salaries;
      }
      function updateSalary(users,salaries) {
        users.map(function(user) {
          user['salary'] = salaries[i];
          user['age'] = age;
          i++;
        });
      }
      function manyParms(user,salary,a,b,c,d,e) {
        return a+' '+b+' '+c+' '+d+' '+e+' '+user.name+'. You made \$'+salary;
      }
        
      """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['users'][0]['name'],'Khurram');
    expect(context['users'][0]['salary'],10000);
    expect(context['users'][1]['salary'],900000);
    expect(context['users'][1]['age'],3);
    expect(rtnValue,'Hello How are you today, Khurram. You made \$10000');
  });
  test('functiontest', () async {
    String codeToEvaluate = """
        var original = 5;
        //myText.text = "It's changed";
        
        function addMe(num) {
          original = original + num;
        }
        //addMe(10);
       """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['original'],5);
  });
  test('functiondecalltest', () async {
    String codeToEvaluate = """
       ensemble.setNames('Khurram','Mahmood');
       ensemble.setDate('8-09-2022');
       ensemble.setNamesAndDate(ensemble.firstName+'!',ensemble.lastName+'!',ensemble.getDate()+'!');
       return ensemble.firstName == 'Khurram!' && ensemble.lastName == 'Mahmood!' && ensemble.date == '8-09-2022!';
      """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['ensemble'].firstName,'Khurram!');
    expect(context['ensemble'].date,'8-09-2022!');
    expect(rtnValue,true);
  });
  test('treatJsFunctionAsStringTest', () async {
    String code = """
        var a = {
          "label": {
              "abc": function (value) {
                return value;
              },
              "nested": {
                  "nested2": {
                      "nested3": function yyy(v) {
                          str = "I am a function";
                          a = 'hello';
                          return 'hello';
                       }
                  }
              }
           },
           "toplevel": function abc (v) {
              log("hello");
            },
           "abc": 'hello',
           'xyz': '123'
        };
        return a;
       """;
    Map<String, dynamic> context = initContext();
    dynamic map = JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    JSInterpreter.toJSString(map);
    expect(map['label']['abc'](['hello']),'hello');
  });
  test('Primitive in code', () {
    Map<String, dynamic> context = initContext();

    Invokable myText = Ensemble('whatever');
    InvokableController.setProperty(myText,'text', 'Hi');
    context["text1"] = myText;
    context["text2"] = "World";

    expect(JSInterpreter.fromCode('text1.text', SimpleContext(context)).evaluate(), 'Hi');
    expect('Hello '+JSInterpreter.fromCode('text2', SimpleContext(context)).evaluate(), 'Hello World');


  });

  test('filter function', () async {
    Map<String, dynamic> context = {
      'items': ['one', 'two', 'three'],
      'nested': [
        {'id': 1, 'label': 'eggs', 'type': ''},
        {'id': 2, 'label': 'strawberry', 'type': 'fruit'},
        {'id': 3, 'label': 'nut'}
      ]
    };

    String code = """
      var flatList = items.filter(function(e,index) {
        console.log(index);
        return e != 'two';
      });
      
      var nestedList = nested.filter(function(e) {
        return e['type'] == 'fruit'
      });
    """;
    
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();

    // simple object
    expect(context['flatList'].length, 2);
    expect(context['flatList'][0], context['items'][0]);
    expect(context['flatList'][1], context['items'][2]);

    // nested object
    expect(context['nestedList'].length, 1);
    expect(context['nestedList'][0]['label'], 'strawberry');

    // ensure original values have not changed
    expect(context['items'].length, 3);
    expect(context['nested'].length, 3);

  });
  test('string_functions', () {
    Map<String, dynamic> context = initContext();

    String code = """
        var str = 'the ensemble is GREAT';
        var len = 'Hello'.length;
        var ensembleStr = str.substring(4,4+'ensemble'.length);
        var isGreat = str.substring(4);
        var four = str.indexOf('ensemble');
        var minusOne = str.indexOf('whatever');
        var upperCase = str.toUpperCase();
        var lowerCase = str.toLowerCase();
        var base64 = str.btoa();
        var equalsEncoded = base64 == btoa(str);
        var decoded = atob(base64);
        var equalsDecoded = decoded == base64.atob();
        """;

    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(context['ensembleStr'],'ensemble');
    expect(context['len'],5);
    expect(context['isGreat'],'ensemble is GREAT');
    expect(context['four'],4);
    expect(context['minusOne'],-1);
    expect(context['upperCase'],'the ensemble is great'.toUpperCase());
    expect(context['lowerCase'],'the ensemble is great'.toLowerCase());
    expect(context['base64'],'dGhlIGVuc2VtYmxlIGlzIEdSRUFU');
    expect(context['equalsEncoded'],true);
    expect(context['decoded'],'the ensemble is GREAT');
    expect(context['equalsDecoded'],true);

  });
  test('array_functions', () {
    Map<String, dynamic> context = initContext();

    String code = """
        var arr = ['a','b','c','d'];
        var b = arr.at(1);
        var arr2 = arr.concat(['e','f']);
        var f = arr2.find(function (element)  { 
              var rtn = ( element == 'f' )? true : false;
              return rtn;
         });
         var includes = arr2.includes('e');
         var str = arr.join();
         var str2 = arr.join('-');
         var str3 = arr.join('');
         var last = arr2.pop(); 
         var nums = [1,2,3,4,5];
         var sum = nums.reduce(function (value, element) {
            return value + element;
            });
         var reversed = arr.reverse();
        """;

    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(context['b'],'b');
    expect(context['arr2'][4],'e');
    expect(context['f'],'f');
    expect(context['includes'],true);
    expect(context['str'],'a,b,c,d');
    expect(context['str2'],'a-b-c-d');
    expect(context['str3'],'abcd');
    expect(context['last'],'f');
    expect(context['arr2'].length,5);
    expect(context['sum'],15);
    expect(context['reversed'][0],'d');
  });
  test('console_log_test', () {
    Map<String, dynamic> context = initContext();
    context['json'] = json.decode('{"abc":"xyz"}');
    String code = """
      var str = 'I am a sample message to be printed on the console';
      console.log('Logging jsonmap - '+json);
      console.log(json);
      console.log('logging - '+str);
      """;
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
  });
  test('ifthenexpression', () {
    Map<String, dynamic> context = {
      'items': ['one', 'two', 'three'],
      'nested': [
        {'id': 1, 'label': 'eggs', 'type': ''},
        {'id': 2, 'label': 'strawberry', 'type': 'fruit'},
        {'id': 3, 'label': 'nut'}
      ]
    };
    String code = """
      var _null = null;
      var zero = 0;
      var a = (items.length > 0 && items.length < 4 ? items.length == 3 || items.length == 1 ? false : true : false);
      var b = items[0] == 'two' || items[0] == 'one';//see https://github.com/EnsembleUI/ensemble/issues/534
      var c = _null || zero;
      var d = zero || _null;
      """;
    var rtn = JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(context['a'],false);
    expect(context['b'],true);
    expect(context['c'],0);
    expect(context['d'],null);
  });
  test('datefunction', () {
    Map<String, dynamic> context = {};
    String code = """
      var date = new Date();
      var yesterday = date - 1000 * 60 * 60 * 24; 
      yesterday = new Date(yesterday).getDay();
      // Methods
      var getTime = date.getTime();
      var getFullYear = date.getFullYear();
      var getMonth = date.getMonth();
      var getDate = date.getDate();
      var getHours = date.getHours();
      var getMinutes = date.getMinutes();
      var getSeconds = date.getSeconds();
      var getMilliseconds = date.getMilliseconds();
      var getDay = date.getDay();
      var setTime = date.setTime(1653318712345);
      
      // UTC methods
      var utc = Date.UTC(2022, 5, 2, 10, 49, 7, 521);
      """;
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    // DateTime date = DateTime.now();
    // expect(context['getTime'], isNotNull);
    // expect(context['getFullYear'], date.year);
    // expect(context['getMonth'], date.month - 1);
    // expect(context['getDate'], date.day);
    // expect(context['getHours'], date.hour);
    // expect(context['getMinutes'], date.minute);
    // expect(context['getSeconds'], date.second);
    // expect(context['getDay'], date.day % 7);
    // expect(context['setTime'], 1653318712345);
    // expect(context['utc'], 1654166947521);
    // expect(context['yesterday'], (date.day - 1) % 7);
  });
  test('refinarrayorobject', () {
    Map<String, dynamic> context = {
      'items': ['one', 'two', 'three'],
      'nested': [
        {'id': 1, 'label': 'eggs', 'type': ''},
        {'id': 2, 'label': 'strawberry', 'type': 'fruit'},
        {'id': 3, 'label': 'nut'}
      ]
    };
    String code = """
      var myVar = "abc";
      var res = [
              {'1':[myVar,'abc']}];
      return res[0]['1'][0];
      """;
    var rtn = JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(rtn,context['myVar']);
  });
  test('regexmatchandmatchall', () {
    Map<String, dynamic> context = {};
    String code = """
      var regexp = /[A-Z]/g;
      var regexp2 = /property\([^)]+\)manage/g;
      var htmlString = '<html><head></head><body>Sharjeel modified the trip. <a data-ios-target="booking:05a1ead9-cf90-4bcf-8e56-0c469ffa7f4e" data-ios-target-v1="internal:booking:05a1ead9-cf90-4bcf-8e56-0c469ffa7f4e" href="https://myplace.co/app/property/831c18d1-3557-4106-9247-932a4a5c416c/manage?booking=05a1ead9-cf90-4bcf-8e56-0c469ffa7f4e">Review</a></body></html>';
      var m = htmlString.matchAll(regexp2);
      var matches = 'Hello World'.matchAll(regexp );
      var match = 'Hello World'.match(/[A-Z]/g);
      var secondMatch = 'Hello World'.matchAll(/[A-Z]/g)[1];
      """;
    var rtn = JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(context['matches'][0], 'H');
    expect(context['matches'][1], 'W');
    expect(context['match'][0], 'H');
    expect(context['secondMatch'], 'W');
  });
  test('invokeapitest', () {
    Map<String, dynamic> context = initContext();
    String code = """
      ensemble.invokeAPI('myAPI',{'input1': 123, 'input2': 'hello'});
      """;
    var rtn = JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
  });
  test('objectexpressiontext', () {
    Map<String, dynamic> context = initContext();
    String code = """
                            var result = {
                                'hello': ['how','are','you'],
                                data: {'abc': [1,2,3,4]},
                                unsetData: {},
                                validationErrors: []
                            };
                            console.log(JSON.stringify(result));
      """;
    var rtn = JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(context['result']['data']['abc'][1],2);
  });
  test('nestedforeach', () {
    Map<String, dynamic> context = initContext();
    String code = """
    var tiles = [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3, 4, 5, 6, 7];
    var indices = [0,1,2,3,4,5,6,7];

    indices.forEach(function(num){
      var temps = [1,2];
      temps.forEach(function(num1,index){
        var randomIndex = Math.floor(Math.random() * 16);
        console.log('Random Index :' + randomIndex+' index='+index);
        if(tiles[randomIndex] == undefined) {
          tiles[randomIndex] = num;
        }
      });
    });
      """;
    var rtn = JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    //expect(context['result']['data']['abc'][1],2);
  });
  test('functionscope', () {
    Map<String, dynamic> context = initContext();
    String code = """
      var counter = 0;
      function increment() {
        counter++;
        console.log('inside '+counter);
      }
      """;
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    code = """
      counter = 0;
      increment();
      console.log('outside '+counter);
      """;
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(context['counter'],1);
  });
  test('2darrayissue', () {
    Map<String, dynamic> context = initContext();
    String code = """
function createRandomizedTiles() {

    var tilesIndexMapping = [[0,-1], [1,-1], [2,-1],[3,-1], [4,-1], [5,-1], [6,-1], [7,-1],[8,-1], [9,-1], [10,-1],[11,-1], [12,-1], [13,-1], [14,-1], [15,-1]]; 


      for (var i = 0; i < 8; i++) {
        //console.log('i is:' + i);
        //create a random value between 0 and 16 
        //corersponding to the tile positions
        var count = 0; 
        while(count < 2) {
          var val = Math.floor(Math.random() * 16);
          console.log('val: ' + val);
          if(tilesIndexMapping[val][1] == -1) {
            tilesIndexMapping[val][1] = i;
            // console.log('val: ' + val);
            console.log('i: ' + i);
            console.log('tilesIndexMapping['+ val+'][1] ' + tilesIndexMapping[val][1]);
            count = count + 1;
          }
          //console.log('val: ' + val);
          //console.log('count: ' + count);
        }
      } 
      return tilesIndexMapping;
  }
  var tilesIndexMapping = createRandomizedTiles();
  tilesIndexMapping.forEach(function (item) {
    console.log(item[1]);
  });
      """;
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    //expect(context['counter'],1);
  });
  test('ORTest', () {
    Map<String, dynamic> context = initContext();
    String code = """
      var name = null;
      var messages = [];
        if (name == null) {
          messages.push('worked');
        }
        if (name == null || name.length == 0) {
          messages.push('worked');
        }
      """;
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    expect(context['messages'][0],'worked');
    expect(context['messages'][1],'worked');
  });
  test('mapTest - 687', () async {
    String codeToEvaluate = """
      var arr = ['Transportation', 'Groceries', 'Investments', 'Shopping', 'Entertainment', 'Dining', 'Healthcare'];
      var newArr = arr.map(function(value){
        return value;
      });
      console.log(newArr);
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
    expect(context['newArr'][1],'Groceries');
  });
  test('stringreplace', () async {
    String codeToEvaluate = """
    // Given date string
    var p = 'The quick brown fox jumps over the lazy dog. If the dog reacted, was it really lazy?';
    var replacedDog = p.replace('dog', 'monkey');
    var replacedAllDogs = p.replaceAll('dog', 'monkey');
    console.log('replacedAllDogs='+replacedAllDogs);
    var replacedRegex = p.replace(/Dog/i, 'ferret');
    console.log('replacedRegex='+replacedRegex);
    var replacedAllRegex = p.replaceAll(/Dog/i, 'ferret');
    console.log('replacedAllRegex='+replacedAllRegex);
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['replacedDog'],
        'The quick brown fox jumps over the lazy monkey. If the dog reacted, was it really lazy?');
    expect(context['replacedAllDogs'],
        'The quick brown fox jumps over the lazy monkey. If the monkey reacted, was it really lazy?');
    expect(context['replacedRegex'],
        'The quick brown fox jumps over the lazy ferret. If the dog reacted, was it really lazy?');
    expect(context['replacedAllRegex'],
        'The quick brown fox jumps over the lazy ferret. If the ferret reacted, was it really lazy?');
  });
  // test('jsonstringify', () async {
  //   var dateTime = DateTime(2006, 0, 2, 15, 4, 5);
  //   print('datetime=${jsonEncode(dateTime)}');
  //   String codeToEvaluate = """
  //     console.log(JSON.stringify({ x: 5, y: 6 }));
  //     // Expected output: '{"x":5,"y":6}'
  //
  //     console.log(JSON.stringify([3, 'false', false]));
  //     // Expected output: '[3,"false",false]'
  //
  //
  //     console.log(JSON.stringify(new Date(2006, 0, 2, 15, 4, 5)));
  //     // Expected output: '"2006-01-02T15:04:05.000Z"'
  //     """;
  //   Map<String, dynamic> context = initContext();
  //   JSInterpreter.fromCode(codeToEvaluate,SimpleContext(context)).evaluate();
  //   //expect(context['newArr'][1],'Groceries');
  // });
  test('issue:725 - bindingmap', () async {
    String codeToEvaluate = """
      ensemble.storage.merchants[name].merchantLogo
      """;
    Program ast = JSInterpreter.parseCode(codeToEvaluate);
    List<String> bindings = Bindings().resolve(ast);
    expect(bindings.length, 2);
    expect(bindings[0], 'ensemble.storage.merchants');
    expect(bindings[1], 'name');
  });
  test('andorconditionals - 758', () async {
    String codeToEvaluate = """
      var cond1 = true;
      var cond2 = true;
      var cond3 = false;
      //left is false in &&
      if ( response.abc && response.abc.lmn == 'abc' ) {
        cond1 = false;
      }
      response.abc = {};
      //left is true and right is false
      if ( response.abc && response.abc.lmn == 'abc' ) {
        cond2 = false;
      }
      response.abc.lmn = 'abc';
      //left and right are true
      if ( response.abc && response.abc.lmn == 'abc' ) {
        cond3 = true;
      }
      var cond4 = true;
      var cond5 = false;
      var cond6 = false;
      var cond7 = false;         
      //left is false and right is false in ||
      if ( response.xyz || response.abc.lmn == 'xyz' ) {
        cond4 = false;
      }
      response.xyz = {};
      //left is true and right is false
      if ( response.xyz != null || response.xyz.lmn == 'abc' ) {
        cond5 = true;
      }
      response.xyz.lmn = 'abc';
      //left and right are true
      if ( response.xyz != null || response.xyz.lmn == 'abc' ) {
        cond6 = true;
      }
      //left is false and right is true
      if ( response.jjj != null || response.xyz.lmn == 'abc' ) {
        cond7 = true;
      }        
      """;
    Map<String, dynamic> context = initContext();
    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['cond1'],true);
    expect(context['cond2'],true);
    expect(context['cond3'],true);
    expect(context['cond4'],true);
    expect(context['cond5'],true);
    expect(context['cond6'],true);
    expect(context['cond7'],true);
  });
  test('issue 34 - assignVarOnDeclaration', () async {
    String codeToEvaluate = """
      var var1 = 123;
      var var2 = var1;
      
      """;
    Map<String, dynamic> context = initContext();
    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['var2'],123);
  });
  test('iterate_over_object', () async {
    Map<String, dynamic> headers = {};
    headers['abc'] = 'xyz';
    headers['def'] = 123;
    headers['ghi'] = '456';
    Map<String, dynamic> context = initContext();
    //context['headers'] = headers;

    String codeToEvaluate = """
      var headers = {};
      headers['abc'] = 'xyz';
      headers['def'] = 123;
      headers['ghi'] = '456';      
      var keys = headers.keys();
      console.log('keys:');
      keys.forEach(function(key) {
        console.log(key + ':' + headers[key]);
      });
      console.log('values:');
      headers.values().forEach(function(val) {
        console.log(val);
      });
      console.log('entries:');
      headers.entries().forEach(function(entry) {
        console.log(entry.key + ':' + entry.value);
      });      
      """;

    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    //expect(context['var2'],123);
  });
  test('json-functions', () async {
    Map<String, dynamic> context = initContext();

    String codeToEvaluate = """
      var json = {"abc":"xyz","date": new Date() };
      var str = JSON.stringify(json);
      console.log(str);    
      var json2 = JSON.parse(str);
      console.log(json2);
      var date = new Date();
      console.log(date.toString());
      var event = new Date('2023-11-02 17:07:35.053068');
      console.log("event -> "+event.toString());
      // Expected output: "Wed Oct 05 2011 16:48:00 GMT+0200 (CEST)"
      // Note: your timezone may vary
      
      console.log(event.toISOString());
      // Expected output: "2011-10-05T14:48:00.000Z"
      """;

    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['str'].startsWith('{"abc":"xyz","date":'),true);
    expect(context['json2']['abc'],'xyz');
  });
  test('increment-mac-address', () async {
    Map<String, dynamic> context = initContext();

    String codeToEvaluate = """
      function incrementMAC(mac, increment) {
        var hexParts = mac.split(':');
        var numericValue = parseInt(hexParts.join(''), 16);
        var incrementedValue = numericValue + increment;
        var incrementedHex = incrementedValue.toString(16).padStart(12, '0');
        
        var newMac = [];
        for (var i = 0; i < 12; i += 2) {
        newMac.push(incrementedHex.substring(i, i + 2));
        }
        
        return newMac.join(':').toUpperCase();
      }  
      var macAddresses = [
          '00:16:3E:2B:6F:FF',
          '06:00:00:00:00:01',
          '08:00:27:13:69:AD',
          '00:0C:29:3D:7B:6E'
      ];
      var expectedValues = [];
      macAddresses.forEach(function(mac) {
        expectedValues.push(incrementMAC(mac, 1));
      });

      """;

    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['expectedValues'][0] == '00:16:3E:2B:70:00',true);
    expect(context['expectedValues'][1] == '06:00:00:00:00:02',true);
    expect(context['expectedValues'][2] == '08:00:27:13:69:AE',true);
    expect(context['expectedValues'][3] == '00:0C:29:3D:7B:6F',true);
  });
  test('increment', () async {
    String codeToEvaluate = """
      var a = [{player1: {score: 1}}];
       //a.score++;
       console.log(a[0].player1.score);
      a[0]['player1']['score']++;
      var b = 2;
      b++;
      var c = --a[0]['player1']['score'];
      var d = a[0]['player1']['score']--;
      
      var e = ++c;
      var f = d++;
      
      """;
    Map<String, dynamic> context = initContext();
    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['a'][0]['player1']['score'],0);
    expect(context['b'],3);
    expect(context['c'],2);
    expect(context['d'],2);
    expect(context['e'],2);
    expect(context['f'],1);
  });
  test('regexstringreplace', () async {// Output: (925) 935-1569

    String codeToEvaluate = r"""
        var numberSt = "9252950000";
        var formattedResult = numberSt.replaceAll(/^([2-9]\d{2})([2-9]\d{2})(\d{4})$/, 
                  '($1) $2-$3');
        var ssn = "234567890".replace(/^(\d{3})(\d{2})(\d{4})$/, '$1-$2-$3');
        var unformattedssn = ssn.replaceAll(/-/g, '');
        
        var fileExtension = "example.png".match(/(?:\.([0-9a-z]+))$/i)[0];
        
        var phone = '408-230-6845'.replaceAll(/\D/g, '');
        console.log(phone);
        
      """;
    Map<String, dynamic> context = initContext();
    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['formattedResult'],'(925) 295-0000');
    expect(context['ssn'],'234-56-7890');
    expect(context['unformattedssn'],'234567890');
    expect(context['fileExtension'],'.png');

  });
  test('regexpfori18n', () async {// Output: (925) 935-1569
    final RegExp i18nExpression = RegExp(r'\br@[\w\.]+');
    expect(
        "abcr@gmail.com".replaceAllMapped(i18nExpression, (match) {
          return match.input.substring(match.start, match.end);
        }),
        'abcr@gmail.com');
    expect(
        "abc r@gmail.com".replaceAllMapped(i18nExpression, (match) {
          return match.input.substring(match.start, match.end);
        }),
        'abc r@gmail.com');
    expect(
        "abc@gmail.com".replaceAllMapped(i18nExpression, (match) {
          return match.input.substring(match.start, match.end);
        }),
        'abc@gmail.com');
  });
  group('Regex Test for js single expressions in Utils.onlyExpression', () {
    // Define the RegExp
    final RegExp onlyExpression = RegExp(
        r'''^\$\{([^}]+)\}$'''
    );

    test('should match single expression and extract content', () {
      var match = onlyExpression.firstMatch(r'''${phone_wdg.value.replaceAll(/\D/g, '')}''');
      expect(match, isNotNull);
      expect(match?.group(1), equals('phone_wdg.value.replaceAll(/\\D/g, \'\')'));
    });

    test('should return null for multiple expressions', () {
      var match = onlyExpression.firstMatch(r'''${abc.go()} ${efg.hello()}''');
      expect(match, isNull);
    });

    test('should return null for no expression', () {
      var match = onlyExpression.firstMatch('No expression here');
      expect(match, isNull);
    });

    test('should handle complex expressions within braces', () {
      var match = onlyExpression.firstMatch(r'''${complex.expression(with, various_characters)}''');
      expect(match, isNotNull);
      expect(match?.group(1), equals('complex.expression(with, various_characters)'));
    });

    test('should return null for unbalanced braces', () {
      var match = onlyExpression.firstMatch(r'''${unbalanced.expression''');
      expect(match, isNull);
    });
    // Test for a string with the expression repeated multiple times
    test('should return null for string with multiple separate expressions', () {
      var match = onlyExpression.firstMatch(r'''${phone_wdg.value.replaceAll(/\D/g, '')} ${phone_wdg.value.replaceAll(/\D/g, '')}''');
      expect(match, isNull);
    });

// Test for a string with a complex expression inside ${...}
    test('should match a complex single expression within braces', () {
      var match = onlyExpression.firstMatch(r'''${phone_wdg.value.replaceAll(/\D/g, '') + phone_wdg.value.replaceAll(/\D/g, '') + 'hello'}''');
      expect(match, isNotNull);
      expect(match?.group(1), equals('phone_wdg.value.replaceAll(/\\D/g, \'\') + phone_wdg.value.replaceAll(/\\D/g, \'\') + \'hello\''));
    });

// Test for a string with complex content but not in the correct format
    test(r'should return null for complex content not enclosed in ${...}', () {
      var match = onlyExpression.firstMatch(r'''phone_wdg.value.replaceAll(/\D/g, '') + phone_wdg.value.replaceAll(/\D/g, '') + 'hello''');
          expect(match, isNull);
    });

// Test for a string with multiple complex expressions
    test('should return null for multiple complex expressions', () {
      var match = onlyExpression.firstMatch(r'''${phone_wdg.value.replaceAll(/\D/g, '') + 'something'} ${phone_wdg.value.replaceAll(/\D/g, '') + 'anotherThing'}''');
      expect(match, isNull);
    });
// Test for a string starting with a valid expression followed by additional text
    test('should return null for valid expression followed by external text', () {
      var match = onlyExpression.firstMatch(r'''${phone_wdg.value.replaceAll(/\D/g, '')} hello''');
      expect(match, isNull);
    });

// Test for a complex expression within braces including concatenation
    test('should match complex expression with concatenation inside braces', () {
      var match = onlyExpression.firstMatch(r'''${phone_wdg.value.replaceAll(/\D/g, '') + 'hello'}''');
      expect(match, isNotNull);
      expect(match?.group(1), equals('phone_wdg.value.replaceAll(/\\D/g, \'\') + \'hello\''));
    });

  });
  group('Contain Expression Tests', () {
    // Define the RegExp for matching expressions
    final RegExp containExpression = RegExp(
        r'''\$\{([^}{]+(?:\{[^}{]*\}[^}{]*)*)\}'''
    );


    test('should match single expression with replaceAll', () {
      var matches = containExpression.allMatches(r'''${phone_wdg.value.replaceAll(/\D/g, '')}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(1));
      expect(matches[0], equals(r'''${phone_wdg.value.replaceAll(/\D/g, '')}'''));
    });

    test('should match multiple expressions in a string', () {
      var matches = containExpression.allMatches(r'''${phone_wdg.value.replaceAll(/\D/g, '')} Hello ${user.name.replaceAll(/\s/g, '_')}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(2));
      expect(matches, containsAll([r'''${phone_wdg.value.replaceAll(/\D/g, '')}''', r'''${user.name.replaceAll(/\s/g, '_')}''']));
    });

    test('should match expressions with various regex patterns', () {
      var matches = containExpression.allMatches(r'''${data.format(/x+/g, 'X')} and ${info.replace(/[^a-zA-Z]/g, '')}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(2));
      expect(matches, containsAll([r'''${data.format(/x+/g, 'X')}''', r'''${info.replace(/[^a-zA-Z]/g, '')}''']));
    });

    test('should not match if no expression present', () {
      var matches = containExpression.allMatches('Just a regular string').map((e) => e.group(0)).toList();
      expect(matches, isEmpty);
    });

    test('should handle nested curly braces correctly', () {
      var matches = containExpression.allMatches(r'''${compute({x: 1, y: 2})}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(1));
      expect(matches[0], equals(r'''${compute({x: 1, y: 2})}'''));
    });
// Test for a string with a complex expression including numbers and symbols
    test('should match expression with numbers and symbols', () {
      var matches = containExpression.allMatches(r'''${value.calculate(42, @symbol)}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(1));
      expect(matches[0], equals(r'''${value.calculate(42, @symbol)}'''));
    });

// Test for a string with a mixture of text and expressions
    test('should match expressions within text', () {
      var matches = containExpression.allMatches(r'''Text before ${expr1} and text after ${expr2}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(2));
      expect(matches, containsAll([r'''${expr1}''', r'''${expr2}''']));
    });

// Test for a string with multiple expressions including function calls and operations
    test('should match multiple complex expressions', () {
      var matches = containExpression.allMatches(r'''${func1(arg1)} some text ${func2(arg2) + func3(arg3)}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(2));
      expect(matches, containsAll([r'''${func1(arg1)}''', r'''${func2(arg2) + func3(arg3)}''']));
    });

// Test for a string with an expression containing special characters
    test('should match expression with special characters', () {
      var matches = containExpression.allMatches(r'''${special.chars["<>%$#"]()}''').map((e) => e.group(0)).toList();
      expect(matches, hasLength(1));
      expect(matches[0], equals(r'''${special.chars["<>%$#"]()}'''));
    });

  });

  test('OR between empty or null', () async {
    String codeToEvaluate = r"""
      var a = null;
      var b = a || 'hello';
      var c = a || '';
      a = '';
      var d = a || 'hello';
      var e = a || '';
      var f = e || null;
      var g = null || '';
      
      """;
    Map<String, dynamic> context = initContext();
    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['a'],'');
    expect(context['b'],'hello');
    expect(context['c'],'');
    expect(context['d'],'hello');
    expect(context['e'],'');
    expect(context['f'],null);
    expect(context['g'],'');
  });
  test('optional arguments unknown argumemts', () async {
    String codeToEvaluate = r"""
      var f = function(a,b) {
        return a+(b || 0);
      }
      var a = f(1);
      var b = f(1,2);
      var c = f(1,2,3);
      
      """;
    Map<String, dynamic> context = initContext();
    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['a'],1);
    expect(context['b'],3);
    expect(context['c'],3);

  });
  test('function as variable', () async {
    String codeToEvaluate = r"""
      var f = function(a,b) {
        return a+b;
      }
      var a = f(1,2);
      console.log(a);
      
      """;
    Map<String, dynamic> context = initContext();
    var rtn = JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['a'],3);

  });
  group('Unary Operator Tests', () {
    test('Negation Operator (-)', () {
      var code = 'var result = -5;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], -5);
    });

    test('Unary Plus Operator (+)', () {
      var code = 'var result = +"3";';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], 3);
    });

    test('Increment Operator (++)', () {
      var code = 'var num = 5; var result = ++num;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['num'], 6);
      expect(context['result'], 6);
    });

    test('Decrement Operator (--)', () {
      var code = 'var num = 5; var result = --num;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['num'], 4);
      expect(context['result'], 4);
    });

    test('Bitwise NOT Operator (~)', () {
      var code = 'var result = ~5;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], ~5);
    });

    test('Typeof Operator', () {
      var code = 'var result = typeof 5;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], 'number');
    });

    test('Logical NOT Operator (!)', () {
      var code = 'var result = !true;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], false);
    });

    // Add more tests as needed
  });
  group('Logical NOT Operator (!) Tests', () {
    test('!null should be true', () {
      var code = 'var result = !null;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], true);
    });

    test('!empty string should be true', () {
      var code = 'var result = !"";';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], true);
    });

    test('!non-empty string should be false', () {
      var code = 'var result = !"hello";';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], false);
    });

    test('!0 should be true', () {
      var code = 'var result = !0;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], true);
    });

    test('!non-zero number should be false', () {
      var code = 'var result = !42;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], false);
    });

    test('!false should be true', () {
      var code = 'var result = !false;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], true);
    });

    test('!true should be false', () {
      var code = 'var result = !true;';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], false);
    });
  });
  group('Logical NOT Operator in Control Structures', () {
    test('! in if condition with true value', () {
      var code = '''
      var result;
      if (!true) {
        result = "false branch";
      } else {
        result = "true branch";
      }
    ''';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], 'true branch');
    });

    test('! in if condition with false value', () {
      var code = '''
      var result;
      if (!false) {
        result = "false branch";
      } else {
        result = "true branch";
      }
    ''';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], 'false branch');
    });

    test('! in ternary conditional with non-empty string', () {
      var code = 'var result = !"hello" ? "false branch" : "true branch";';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], 'true branch');
    });

    test('! in ternary conditional with empty string', () {
      var code = 'var result = !"" ? "false branch" : "true branch";';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], 'false branch');
    });

    test('! in ternary conditional with null', () {
      var code = 'var result = !null ? "false branch" : "true branch";';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['result'], 'false branch');
    });

    // Add more tests as needed to cover various scenarios and data types
  });
  test('doubele !!', () {
    var code = 'var result = "abc"; console.log(!!result);';
    var context = initContext();
    JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
    //expect(context['result'], 'false branch');
  });
  group('URI Encoding and Decoding Tests', () {
    test('encodeURIComponent encodes URI components', () {
      var code = 'var encoded = encodeURIComponent("Hello, world!");';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['encoded'], 'Hello%2C%20world!');
    });

    test('decodeURIComponent decodes URI components', () {
      var code = 'var decoded = decodeURIComponent("Hello%2C%20world%21");';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['decoded'], 'Hello, world!');
    });

    test('encodeURI encodes full URI without affecting special URI characters', () {
      var code = 'var fullEncoded = encodeURI("https://example.com/?q=Hello, world!");';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['fullEncoded'], 'https://example.com/?q=Hello,%20world!');
    });

    test('decodeURI decodes full URI without affecting special URI characters',
        () {
      var code =
          'var fullDecoded = decodeURI("https://example.com/?q=Hello,%20world!");';
      var context = initContext();
      JSInterpreter.fromCode(code, SimpleContext(context)).evaluate();
      expect(context['fullDecoded'], 'https://example.com/?q=Hello, world!');
    });
  });
  group('InvokableMath Method Tests', () {
    // Testing max with various inputs
    test('max with multiple numbers', () {
      String codeToEvaluate = """
      var result = Math.max(1, 5, 3, 4, 2);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 5);
    });

    test('max with negative numbers', () {
      String codeToEvaluate = """
      var result = Math.max(-10, -20, -30);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], -10);
    });

    // Testing min with various inputs
    test('min with multiple numbers', () {
      String codeToEvaluate = """
      var result = Math.min(10, 5, 15, 20);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 5);
    });

    test('min with string and number mix', () {
      String codeToEvaluate = """
      var result = Math.min('100', 50, '25', 75);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 25);
    });

    // Testing round with various inputs
    test('round with float number', () {
      String codeToEvaluate = """
      var result = Math.round('2.5');
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 3);
    });

    test('round with negative float', () {
      String codeToEvaluate = """
      var result = Math.round(-2.3);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], -2);
    });

    // Additional tests for robustness
    test('abs with a string number', () {
      String codeToEvaluate = """
      var result = Math.abs('-123');
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 123);
    });

    test('sqrt with a positive number', () {
      String codeToEvaluate = """
      var result = Math.sqrt('16');
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 4);
    });

    test('pow with zero exponent', () {
      String codeToEvaluate = """
      var result = Math.pow(5, 0);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 1);
    });
  });
  group('InvokableMath Negative Tests', () {
    // Test handling of null inputs
    test('max with null argument', () {
      String codeToEvaluate = """
        var result = Math.max(null, 5, 3);
      """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 5);
    });

    test('min with null argument', () {
      String codeToEvaluate = """
        var result = Math.min(null, 10, 2);
      """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0);
    });

    // Test handling of string that cannot be converted to number
    test('round with non-numeric string', () {
      String codeToEvaluate = """
        var result = Math.round('abc');
      """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], null);
    });

    // Test handling of undefined or missing arguments
    test('abs with no arguments', () {
      String codeToEvaluate = """
        var result = Math.abs();
      """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0);
    });

    // Test handling of an excessive number of arguments
    test('sqrt with multiple arguments', () {
      String codeToEvaluate = """
        var result = Math.sqrt(16, 4, 9);
      """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 4); // Assuming it ignores additional arguments
    });

    // Add more negative tests as needed to cover other scenarios and methods
  });
  group('Binary Expressions with nulls', () {
    test('null plus number mimics JavaScript coercion to 0', () {
      String codeToEvaluate = """
      var result = null + 5;
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 5); // null is coerced to 0, result is 5
    });

    test('null logical OR with true', () {
      String codeToEvaluate = """
      var result = null || true;
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // null is falsy, returns second operand
    });

    test('null logical AND with false', () {
      String codeToEvaluate = """
      var result = null && false;
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], null); // null is falsy, returns first operand
    });

    test('String concatenation with null', () {
      String codeToEvaluate = """
      var result = "hello" + null;
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'],
          "hellonull"); // null is converted to "null" for concatenation
    });

    test('null equality with null', () {
      String codeToEvaluate = """
      var result = null == null;
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // null is equal to null
    });

    test('null inequality with 0', () {
      String codeToEvaluate = """
      var result = null != 0;
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // In JavaScript, null is not equal to 0
    });

    test('null less than 1', () {
      String codeToEvaluate = """
      var result = null < 1;
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // null is coerced to 0, 0 < 1 is true
    });
    // Arithmetic Operators
    test('null subtracted by number', () {
      String codeToEvaluate = "var result = null - 5;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], -5); // null is coerced to 0
    });

    test('null multiplied by number', () {
      String codeToEvaluate = "var result = null * 5;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0); // null is coerced to 0
    });

    test('null divided by number', () {
      String codeToEvaluate = "var result = null / 5;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0); // null is coerced to 0
    });

    test('number divided by null', () {
      String codeToEvaluate = "var result = 5 / null;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'],
          double.infinity); // null is coerced to 0, division by 0 is Infinity
    });

    test('null modulo number', () {
      String codeToEvaluate = "var result = null % 5;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0); // null is coerced to 0
    });

    // Logical Operators
    test('true OR null', () {
      String codeToEvaluate = "var result = true || null;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // true is returned immediately
    });

    test('false AND null', () {
      String codeToEvaluate = "var result = false && null;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], false); // false is returned immediately
    });

    // Comparison Operators
    test('null greater than 0', () {
      String codeToEvaluate = "var result = null > 0;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], false); // null is coerced to 0
    });

    test('null greater than or equal to null', () {
      String codeToEvaluate = "var result = null >= null;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // both are coerced to 0
    });

    test('null less than or equal to 0', () {
      String codeToEvaluate = "var result = null <= 0;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // null is coerced to 0
    });

    // Bitwise Operators
    test('null bitwise OR with number', () {
      String codeToEvaluate = "var result = null | 1;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 1); // null is coerced to 0
    });

    test('null bitwise AND with number', () {
      String codeToEvaluate = "var result = null & 1;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0); // null is coerced to 0
    });

    test('null bitwise XOR with number', () {
      String codeToEvaluate = "var result = null ^ 1;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 1); // null is coerced to 0
    });

    test('null shifted left by 1', () {
      String codeToEvaluate = "var result = null << 1;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0); // null is coerced to 0
    });

    test('null shifted right by 1', () {
      String codeToEvaluate = "var result = null >> 1;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], 0); // null is coerced to 0
    });

    // Strict Equality and Inequality
    test('null strictly equal to null', () {
      String codeToEvaluate = "var result = null === null;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // Strict equality
    });

    test('null strictly not equal to 0', () {
      String codeToEvaluate = "var result = null !== 0;";
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['result'], true); // Strict inequality
    });
  });
  //scope tests
  test('Variable Hoisting and Shadowing', () async {
    String codeToEvaluate = """
    var globalVar = 'global';
    function testFunction() {
      var globalVar = 'local';
      return globalVar;
    }
    var result = testFunction();
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['result'], 'local');
    expect(context['globalVar'], 'global');
  });
  test('Function Scope and Arguments', () async {
    String codeToEvaluate = """
    function add(a, b) {
      return a + b;
    }
    var result = add(5, 3);
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['result'], 8);
  });
  test('Updating Global Variables within Functions', () async {
    String codeToEvaluate = """
    var counter = 0;
    function increment() {
      counter++;
    }
    increment();
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['counter'], 1);
  });
  test('Variable Declarations Inside Loops', () async {
    String codeToEvaluate = """
    var sum = 0;
    for (var i = 1; i <= 5; i++) {
      sum += i;
    }
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['sum'], 15);
  });
  test('Nested Functions and Closure', () async {
    String codeToEvaluate = """
    function outer() {
      var outerVar = 'outer';
      function inner() {
        return outerVar;
      }
      return inner();
    }
    var result = outer();
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['result'], 'outer');
  });
  test('Function Expressions and Anonymous Functions', () async {
    String codeToEvaluate = """
    var result = (function(a, b) { return a - b; })(10, 5);
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['result'], 5);
  });
  test('The `this` Keyword Inside Functions', () async {
    String codeToEvaluate = """
    var obj = {
      value: 10,
      increment: function() { this.value++; }
    };
    obj.increment();
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['obj']['value'], 11);
  });
  test('Immediately Invoked Function Expressions (IIFE)', () async {
    String codeToEvaluate = """
    var result = (function() {
      var privateVar = 'secret';
      return privateVar;
    })();
  """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['result'], 'secret');
  });
  group('Using Array.prototype Methods', () {
    test('map function', () async {
      String codeToEvaluate = """
    var numbers = [1, 2, 3, 4, 5];
    var doubled = numbers.map(function(number) { return number * 2; });
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['doubled'], [2, 4, 6, 8, 10]);
    });

    test('filter function', () async {
      String codeToEvaluate = """
    var numbers = [1, 2, 3, 4, 5];
    var even = numbers.filter(function(number) { return number % 2 === 0; });
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['even'], [2, 4]);
    });

    test('forEach function', () async {
      String codeToEvaluate = """
    var numbers = [1, 2, 3];
    var sum = 0;
    numbers.forEach(function(number) { sum += number; });
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['sum'], 6);
    });

    test('reduce function', () async {
      String codeToEvaluate = """
    var numbers = [1, 2, 3, 4, 5];
    var total = numbers.reduce(function(accumulator, number) { return accumulator + number; }, 0);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['total'], 15);
    });

    test('concat function', () async {
      String codeToEvaluate = """
    var arr1 = [1, 2, 3];
    var arr2 = [4, 5, 6];
    var combined = arr1.concat(arr2);
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['combined'], [1, 2, 3, 4, 5, 6]);
    });

    test('find and findIndex functions', () async {
      String codeToEvaluate = """
    var numbers = [4, 6, 8, 10];
    var found = numbers.find(function(number) { return number > 7; });
    var foundIndex = numbers.findIndex(function(number) { return number > 7; });
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['found'], 8);
      expect(context['foundIndex'], 2);
    });

    test('reverse function', () async {
      String codeToEvaluate = """
    var numbers = [1, 2, 3];
    var reversed = numbers.reverse();
    """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['reversed'], [3, 2, 1]);
    });
    test('shift function', () async {
      String codeToEvaluate = """
  var numbers = [1, 2, 3];
  var first = numbers.shift();
  """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['first'], 1);
      expect(context['numbers'], [2, 3]);
    });

    test('unshift function', () async {
      String codeToEvaluate = """
  var numbers = [2, 3];
  var newLength = numbers.unshift(1);
  """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['newLength'], 3);
      expect(context['numbers'], [1, 2, 3]);
    });

    test('splice function', () async {
      String codeToEvaluate = """
      var numbers = [1, 2, 4, 5];
      var removed = numbers.splice(2, 1, 3);
      """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['removed'], [4]);
      expect(context['numbers'], [1, 2, 3, 5]);
    });

    test('some function', () async {
      String codeToEvaluate = """
  var numbers = [1, 2, 3, 4, 5];
  var hasHighNumbers = numbers.some(function(number) { return number > 4; });
  """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['hasHighNumbers'], true);
    });

    test('every function', () async {
      String codeToEvaluate = """
  var numbers = [1, 2, 3];
  var allLessThanFive = numbers.every(function(number) { return number < 5; });
  """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['allLessThanFive'], true);
    });

    test('slice function', () async {
      String codeToEvaluate = """
  var numbers = [1, 2, 3, 4, 5];
  var middle = numbers.slice(1, 4);
  """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['middle'], [2, 3, 4]);
    });

    test('fill function', () async {
      String codeToEvaluate = """
  var numbers = [1, 2, 3, 4, 5];
  numbers.fill(0, 1, 4);
  """;
      Map<String, dynamic> context = initContext();
      JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
      expect(context['numbers'], [1, 0, 0, 0, 5]);
    });

    // Further extend these tests to cover additional scenarios or edge cases as needed.
  });

  test('Reuben date bug', () async {
    String codeToEvaluate = """
      function formatDateRange(dateFrom, dateTo) {
          var months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          var fromParts = dateFrom.split('/');
          var toParts = dateTo.split('/');
      
          var fromMonth = parseInt(fromParts[0], 10) - 1;
          var fromDay = parseInt(fromParts[1], 10);
          var fromYear = parseInt(fromParts[2], 10);
      
          var toMonth = parseInt(toParts[0], 10) - 1;
          var toDay = parseInt(toParts[1], 10);
          var toYear = parseInt(toParts[2], 10);
      
          var fromDate = new Date(fromYear, fromMonth, fromDay);
          var toDate = new Date(toYear, toMonth, toDay);
      
          var formattedFromDate = months[fromDate.getMonth()] + ' ' + ('0' + fromDate.getDate()).slice(-2);
          var formattedToDate = months[toDate.getMonth()] + ' ' + ('0' + toDate.getDate()).slice(-2);
          //var formattedFromDate = months[fromDate.getMonth()] + ' ' + ('0' + fromDate.getDate()).slice(('0' + fromDate.getDate()).length - 2);

          //var formattedToDate = months[toDate.getMonth()] + ' ' + ('0' + toDate.getDate()).slice(('0' + toDate.getDate()).length - 2);          
      
          if (fromDate.getMonth() === toDate.getMonth()) {
              return formattedFromDate + '-' + formattedToDate;
          } else {
              return formattedFromDate + '-' + formattedToDate;
          }
      }
      
      // Example usage:
      var dateFrom = "03/09/2024";
      var dateTo = "03/14/2024";
      console.log(formatDateRange(dateFrom, dateTo)); // Output: Mar 09-14
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();

  });
  test('arrow function with parentheses and return', () async {
    String codeToEvaluate = """
      var numbers = [1, 2, 3, 4, 5];
      
      // Using map with an arrow function that contains a block statement
      var squares = numbers.map((number) => {
        return number * number;
      });
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['squares'], [1, 4, 9, 16, 25]);
  });
  test('arrow function without parm and no parenthesis', () async {
    String codeToEvaluate = """
      var greet = () => 'Hello, World!';
      var hello = greet();
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['hello'], 'Hello, World!');
  });
  test('arrow function without parm and parenthesis', () async {
    String codeToEvaluate = """
      var greet = () => {
        var now = new Date();
        return 'Hello, World!';
      };
      var hello = greet(); 
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['hello'], 'Hello, World!');
  });
  test('arrow function with parentheses, multiple parms and return', () async {
    String codeToEvaluate = """
      var calculateArea = (length, width) => {
        var area = length * width;
        return area;
      };
      
      var area = calculateArea(10, 20); 
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['area'], 200);
  });
  test('arrow function with one parm, no parentheses and automatic return', () async {
    String codeToEvaluate = """
      var numbers = [1, 2, 3, 4, 5];
      
      // Using map with an arrow function that contains a block statement
      var squares = numbers.map((number) => number * number);
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['squares'], [1, 4, 9, 16, 25]);
  });
  test('arrow function with multiple parms, no parentheses and automatic return', () async {
    String codeToEvaluate = """
      var add = (a, b) => a + b;
      
      var n = add(5, 7); // Output: 12

      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate, SimpleContext(context)).evaluate();
    expect(context['n'], 12);
  });
}
