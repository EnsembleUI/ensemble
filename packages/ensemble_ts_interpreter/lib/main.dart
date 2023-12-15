
import 'package:http/http.dart' as http;
import 'package:ensemble_ts_interpreter/action.dart';
import 'package:ensemble_ts_interpreter/api.dart';
import 'package:ensemble_ts_interpreter/layout.dart';
import 'package:flutter/material.dart' hide View;
import 'package:yaml/yaml.dart';
import 'view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  static const String _title = 'Ensemble Demo';

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    /*
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text(_title)),
        body: const MyStatefulWidget(),
      ),
    );
    */
    return const MyStatefulWidget();
  }
}
/// This is the stateful widget that the main application instantiates.
class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({Key? key}) : super(key: key);

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}
Widget buildFrom(YamlMap doc,BuildContext context) {
  late Widget rtn = const Text('did not work');
  if (doc['View'] != null) {
    View v = View.from(doc['View']);
    Map<String, API> apis = APIs.from(doc['APIs']);
    List<EnsembleAction> actions = EnsembleActions.configure(
        v, apis, doc['Actions']);
    Layout l = Layout.from(doc["Layout"], v);
    rtn = l.build(context);
  }
  return rtn;
}
/// This is the private State class that goes with MyStatefulWidget.
class _MyStatefulWidgetState extends State<MyStatefulWidget> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  Future<String> loadAsset(BuildContext context, String name) async {
    return await DefaultAssetBundle.of(context).loadString('assets/' + name);
  }


  final List<String> entries = <String>['Sample1: Guess Gender from Name', 'Sample2: Stock Quotes', 'Sample3: Web View of news'];
  final List<String> entryPaths = <String>['a0dcfefc-298d-42ab-932a-aab70c87891b', '0b66a9d9-9125-46b3-82ec-5b360ab73fbd','c8a19fcf-69c0-4751-9733-032291c83937'];
  final List<int> colorCodes = <int>[600, 500];
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Server Driven UI',
        home: Scaffold(
            appBar: AppBar(title: const Text("Server Driven UI Demo")),
            body: Container(
              child:Center(
                child: Column(
                  children:[
                    Flexible(
                        child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: entries.length,
                        itemBuilder: (BuildContext context, int index) {
                          return GestureDetector(
                              onTap: () {
                                GoToPage(entryPaths[index],entries[index],context);
                              },
                              child: SizedBox(
                                      height: 50,
                                      child: Center(
                                        child: Text(entries[index],
                                        style: const TextStyle(fontWeight: FontWeight.bold)),
                                        )
                          ));
                        },
                        separatorBuilder: (BuildContext context, int index) => const Divider(),
                      )
                    ),
                    const Padding(
                        padding: EdgeInsets.symmetric(vertical:50,horizontal:10),
                          child:Text("Above are just three examples of Server Driven UI. "
                              "\n\nTapping on each will make a request to the sever and fetch the definition of the page alongwith some simple UI logic. \n\nThis the ViewModel. \n\nThis app will parse the ViewModel and create the page dynamically. "
                              "\n\nThe view definition also specifies action handlers, APIs to call and simple logic to use. "
                              "\n\nEnjoy :-) email me at khuram.mahmood@gmail.com if you have questions. "
                            "\n\n\n\nGender API is a free API provided by https://gender-api.com while Stock API is a free API provided by https://www.alphavantage.co/",
                        ))
                  ])))
        ));
  }
}

  /*
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
          appBar: AppBar(title: const Text("Hello")),
          body: FutureBuilder<String>(
            future:loadAsset(context,'basic_conditionals.yaml'),
            builder:(BuildContext context,AsyncSnapshot<String> snapShot) {
              Column rtn = Column();
              if (snapShot.hasData) {
                YamlMap doc = loadYaml(snapShot.requireData);
                rtn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [buildFrom(doc)]
                );
              }
              return rtn;
            }
          )
      )
    );
    */

class SecondRoute extends StatelessWidget {
  String? definition,title;
  SecondRoute({Key? key}) : super(key: key);


  @override
  Widget build(BuildContext context) {
    YamlMap doc = loadYaml(definition!);
    return Scaffold(
      appBar: AppBar(
        title: Text(title!),
      ),
      body: Column (
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [buildFrom(doc,context)]
        )
        /*
        child: ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Go back!'),
        ),*/
      );
  }
}
Future<String> GoToPage(page,title,context) async {
  final response = await http
      .get(Uri.parse('https://pz0mwfkp5m.execute-api.us-east-1.amazonaws.com/dev/screen/content?id=$page'));

  if (response.statusCode == 200) {
    // If the server did return a 200 OK response,
    // then parse the JSON.
    SecondRoute r = SecondRoute();
    r.definition = response.body;
    r.title = title;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) =>  r),
    );
    return response.body;
  } else {
    // If the server did not return a 200 OK response,
    // then throw an exception.
    throw Exception('Failed to load album');
  }
}