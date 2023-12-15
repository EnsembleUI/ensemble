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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['ensembleStore']['session']['login']['contextId'],'123456');
    expect((context['ensemble'] as Ensemble).navigateScreenCalledForScreen,'KPN Home');
  });
  test('expressionTest', () async {
    String codeToEvaluate = """
      ensemble.name
      """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(rtnValue,(context['ensemble'] as Ensemble).name);
  });
  test('propsThroughQuotesTest', () async {
    String codeToEvaluate = """
      var a = 0;
      ensembleStore.session.login.cookie = response.headers['Set-Cookie'].split(';')[a]
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['ensembleStore']['session']['login']['cookie'],context['response']['headers']['Set-Cookie'].split(';')[0]);
  });
  test('arrayAccessTest', () async {
    String codeToEvaluate = """
      users[0] = users[users.length-1];
      users[0];
      """;
    Map<String, dynamic> context = initContext();
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(rtnValue,context['users'][1]);
  });
  test('mapTest', () async {
    String codeToEvaluate = """
      var newUsers = users.map(function (user) {
        user.name += "NEW";
        return user;
      });
      """;
    Map<String, dynamic> context = initContext();
    String origValue = context['users'][1]['name'];
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['newUsers'][1]['name'],origValue+'NEW');
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['users'][0]['name'],'user=John Doe II is 15 years old and has \$12.94');
  });
  test('primitives', () async {
    String codeToEvaluate = """
    var curr = '12.3456';
    curr = curr.tryParseDouble().prettyCurrency();
    users[0]['name'] = 'John has '+curr;
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['users'][0]['name'],'John has \$12.35');
  });
  test('returnExpression', () async {
    String codeToEvaluate = """
       'quick brown fox '+users[0]["name"]+' over the fence and received '+users[0]["name"].length+' dollars'
      """;
    Map<String, dynamic> context = initContext();
    context['users'][0]["name"] = 'jumped';
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(rtnValue,'quick brown fox jumped over the fence and received 6 dollars');
  });
  test('returnIdentifier', () async {
    Map<String, dynamic> context = initContext();
    dynamic rtn = JSInterpreter.fromCode("""age""",context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['users'][0]['age'],'Over Two years old');
  });
  test('ternary', () async {
    String codeToEvaluate = """
          (age > 2)?users[0]['age']='More than two years old':users[0]['age']='2 and under';
      """;
    Map<String, dynamic> context = initContext();
    context['age'] = 1;
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
      """,context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtn = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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

    dynamic rtn = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtn = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    JSInterpreter.fromCode(r'var a = /\d+/;a = a.test("123");',context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic rtnValue = JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
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
    dynamic map = JSInterpreter.fromCode(code, context).evaluate();
    JSInterpreter.toJSString(map);
    expect(map['label']['abc'](['hello']),'hello');
  });
  test('Primitive in code', () {
    Map<String, dynamic> context = initContext();

    Invokable myText = Ensemble('whatever');
    InvokableController.setProperty(myText,'text', 'Hi');
    context["text1"] = myText;
    context["text2"] = "World";

    expect(JSInterpreter.fromCode('text1.text', context).evaluate(), 'Hi');
    expect('Hello '+JSInterpreter.fromCode('text2', context).evaluate(), 'Hello World');


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
      var flatList = items.filter(function(e) {
        return e != 'two';
      });
      
      var nestedList = nested.filter(function(e) {
        return e['type'] == 'fruit'
      });
    """;
    
    JSInterpreter.fromCode(code, context).evaluate();

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

    JSInterpreter.fromCode(code, context).evaluate();
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

    JSInterpreter.fromCode(code, context).evaluate();
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
    JSInterpreter.fromCode(code, context).evaluate();
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
    var rtn = JSInterpreter.fromCode(code, context).evaluate();
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
    JSInterpreter.fromCode(code, context).evaluate();
    DateTime date = DateTime.now();
    expect(context['getTime'], isNotNull);
    expect(context['getFullYear'], date.year);
    expect(context['getMonth'], date.month - 1);
    expect(context['getDate'], date.day);
    expect(context['getHours'], date.hour);
    expect(context['getMinutes'], date.minute);
    expect(context['getSeconds'], date.second);
    expect(context['getDay'], date.day % 7);
    expect(context['setTime'], 1653318712345);
    expect(context['utc'], 1654166947521);
    expect(context['yesterday'], (date.day - 1) % 7);
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
    var rtn = JSInterpreter.fromCode(code, context).evaluate();
    expect(rtn,context['myVar']);
  });
  test('regexmatchandmatchall', () {
    Map<String, dynamic> context = {};
    String code = """
      var regexp = /[A-Z]/g;
      var matches = 'Hello World'.matchAll(regexp );
      var match = 'Hello World'.match(/[A-Z]/g);
      var secondMatch = 'Hello World'.matchAll(/[A-Z]/g)[1];
      """;
    var rtn = JSInterpreter.fromCode(code, context).evaluate();
    expect(context['matches'][0],'H');
    expect(context['matches'][1],'W');
    expect(context['match'],'H');
    expect(context['secondMatch'],'W');
  });
  test('invokeapitest', () {
    Map<String, dynamic> context = initContext();
    String code = """
      ensemble.invokeAPI('myAPI',{'input1': 123, 'input2': 'hello'});
      """;
    var rtn = JSInterpreter.fromCode(code, context).evaluate();
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
    var rtn = JSInterpreter.fromCode(code, context).evaluate();
    expect(context['result']['data']['abc'][1],2);
  });
  test('nestedforeach', () {
    Map<String, dynamic> context = initContext();
    String code = """
    var tiles = [0, 1, 2, 3, 4, 5, 6, 7, 0, 1, 2, 3, 4, 5, 6, 7];
    var indices = [0,1,2,3,4,5,6,7];

    indices.forEach(function(num){
      var temps = [1,2];
      temps.forEach(function(num1){
        var randomIndex = Math.floor(Math.random() * 16);
        console.log('Random Index :' + randomIndex);
        if(tiles[randomIndex] == undefined) {
          tiles[randomIndex] = num;
        }
      });
    });
      """;
    var rtn = JSInterpreter.fromCode(code, context).evaluate();
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
    JSInterpreter.fromCode(code, context).evaluate();
    code = """
      counter = 0;
      increment();
      console.log('outside '+counter);
      """;
    JSInterpreter.fromCode(code, context).evaluate();
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
    JSInterpreter.fromCode(code, context).evaluate();
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
    JSInterpreter.fromCode(code, context).evaluate();
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['newArr'][1],'Groceries');
  });
  test('dateFormIssue', () async {
    DateTime d = DateTime.parse("Wednesday, August 2, 2023");
    String codeToEvaluate = """
    // Given date string
    var givenDateString = "Wednesday August 2, 2023";

    // Convert the given date string to a Date object
    var givenDate = new Date(givenDateString);
      console.log(givenDate);
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    //expect(context['newArr'][1],'Groceries');
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
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    expect(context['replacedDog'],'The quick brown fox jumps over the lazy monkey. If the dog reacted, was it really lazy?');
    expect(context['replacedAllDogs'],'The quick brown fox jumps over the lazy monkey. If the monkey reacted, was it really lazy?');
    expect(context['replacedRegex'],'The quick brown fox jumps over the lazy ferret. If the dog reacted, was it really lazy?');
    expect(context['replacedAllRegex'],'The quick brown fox jumps over the lazy ferret. If the ferret reacted, was it really lazy?');
  });
  test('jsonstringify', () async {
    var dateTime = DateTime(2006, 0, 2, 15, 4, 5);
    print('datetime=${jsonEncode(dateTime)}');
    String codeToEvaluate = """
      console.log(JSON.stringify({ x: 5, y: 6 }));
      // Expected output: '{"x":5,"y":6}'
      
      console.log(JSON.stringify([3, 'false', false]));
      // Expected output: '[3,"false",false]'
      
      
      console.log(JSON.stringify(new Date(2006, 0, 2, 15, 4, 5)));
      // Expected output: '"2006-01-02T15:04:05.000Z"'
      """;
    Map<String, dynamic> context = initContext();
    JSInterpreter.fromCode(codeToEvaluate,context).evaluate();
    //expect(context['newArr'][1],'Groceries');
  });
  test('issue:725 - bindingmap', () async {
    String codeToEvaluate = """
      ensemble.storage.merchants[name].merchantLogo
      """;
    Program ast = JSInterpreter.parseCode(codeToEvaluate);
    List<String> bindings = Bindings().resolve(ast);
    expect(bindings.length,2);
    expect(bindings[0],'ensemble.storage.merchants');
    expect(bindings[1],'name');
  });
  test('andorconditionals - 758', () async {
    String codeToEvaluate = """
      var cond1 = true;
      var cond2 = true;
      var cond3 = false;
      //left is false in &&
      if ( response.abc != null && response.abc.lmn == 'abc' ) {
        cond1 = false;
      }
      response.abc = {};
      //left is true and right is false
      if ( response.abc != null && response.abc.lmn == 'abc' ) {
        cond2 = false;
      }
      response.abc.lmn = 'abc';
      //left and right are true
      if ( response.abc != null && response.abc.lmn == 'abc' ) {
        cond3 = true;
      }
      var cond4 = true;
      var cond5 = false;
      var cond6 = false;
      var cond7 = false;         
      //left is false and right is false in ||
      if ( response.xyz != null || response.abc.lmn == 'xyz' ) {
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
    var rtn = JSInterpreter.fromCode(codeToEvaluate, context).evaluate();
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
    var rtn = JSInterpreter.fromCode(codeToEvaluate, context).evaluate();
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

    var rtn = JSInterpreter.fromCode(codeToEvaluate, context).evaluate();
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

    var rtn = JSInterpreter.fromCode(codeToEvaluate, context).evaluate();
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

    var rtn = JSInterpreter.fromCode(codeToEvaluate, context).evaluate();
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
    var rtn = JSInterpreter.fromCode(codeToEvaluate, context).evaluate();
    expect(context['a'][0]['player1']['score'],0);
    expect(context['b'],3);
    expect(context['c'],2);
    expect(context['d'],2);
    expect(context['e'],2);
    expect(context['f'],1);
  });
}