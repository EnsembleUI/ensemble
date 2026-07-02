import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/context.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:test/test.dart';

dynamic evalJs(String code, [Map<String, dynamic>? context]) {
  final ctx = context ?? <String, dynamic>{};
  return JSInterpreter.fromCode(code, SimpleContext(ctx)).evaluate();
}

void main() {
  group('Practical app-style JS snippets', () {
    test('nested context data, invokable-style functions, arrays, and JSON',
        () {
      final context = <String, dynamic>{
        'response': {
          'body': {
            'data': {
              'items': [
                {'name': 'Ada', 'score': 3},
                {'name': 'Grace', 'score': 5},
                {'name': 'Linus', 'score': 2},
              ],
            },
          },
        },
        'store': {
          'session': {},
        },
        'formatName': (String name) => name.toUpperCase(),
      };
      evalJs('''
        var items = response.body.data.items;
        var selected = items
          .filter(function(item) { return item.score >= 3; })
          .map(function(item, index) {
            return {
              label: formatName(item.name) + ':' + index,
              score: item.score
            };
          });
        store.session.summary = JSON.stringify({
          count: selected.length,
          first: selected[0].label
        });
      ''', context);
      expect(context['store']['session']['summary'],
          '{"count":2,"first":"ADA:0"}');
    });
  });

  group('Practical ES5 control flow', () {
    test('switch matches, falls through, and breaks', () {
      final context = <String, dynamic>{};
      evalJs('''
        var value = 2;
        var out = '';
        switch (value) {
          case 1:
            out += 'one';
            break;
          case 2:
            out += 'two';
          case 3:
            out += 'three';
            break;
          default:
            out += 'default';
        }
      ''', context);
      expect(context['out'], 'twothree');
    });

    test('for loop without condition runs until break', () {
      final context = <String, dynamic>{};
      evalJs('''
        var count = 0;
        for (;;) {
          count++;
          if (count === 3) break;
        }
      ''', context);
      expect(context['count'], 3);
    });

    test('labeled continue and break target outer loops', () {
      final context = <String, dynamic>{};
      evalJs('''
        var out = '';
        outer:
        for (var i = 0; i < 3; i++) {
          for (var j = 0; j < 3; j++) {
            if (i === 1 && j === 0) continue outer;
            if (i === 2 && j === 1) break outer;
            out += i + ':' + j + ';';
          }
        }
      ''', context);
      expect(context['out'], '0:0;0:1;0:2;2:0;');
    });
  });

  group('Practical ES5 operators', () {
    test('void, typeof undeclared, in, instanceof, unsigned shift', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = { a: 1 };
        var arr = [1, 2];
        var r1 = void obj.a;
        var r2 = typeof missingName;
        var r3 = 'a' in obj;
        var r4 = 'z' in obj;
        var r5 = arr instanceof Array;
        var r6 = -1 >>> 1;
      ''', context);
      expect(context['r1'], isNull);
      expect(context['r2'], 'undefined');
      expect(context['r3'], true);
      expect(context['r4'], false);
      expect(context['r5'], true);
      expect(context['r6'], 2147483647);
    });

    test('loose and strict equality follow practical JS coercion', () {
      final context = <String, dynamic>{};
      evalJs('''
        var a = 1 == '1';
        var b = 1 === '1';
        var c = null == undefined;
        var d = false == 0;
        var e = '' == 0;
      ''', context);
      expect(context['a'], true);
      expect(context['b'], false);
      expect(context['c'], true);
      expect(context['d'], true);
      expect(context['e'], true);
    });

    test('global numeric parsing and finiteness use JS coercion', () {
      final context = <String, dynamic>{};
      evalJs('''
        var p1 = parseInt('12px');
        var p2 = parseInt('0x10');
        var p3 = parseInt('0x10', 10);
        var p4 = parseInt('f00d', 16);
        var p5 = parseInt('xyz');
        var f1 = parseFloat('12.5px');
        var f2 = parseFloat('  -0.75rem');
        var f3 = parseFloat('abc');
        var n1 = isNaN('abc');
        var n2 = isNaN(null);
        var n3 = isNaN('');
        var finite1 = isFinite(null);
        var finite2 = isFinite('');
        var finite3 = isFinite('abc');
      ''', context);
      expect(context['p1'], 12);
      expect(context['p2'], 16);
      expect(context['p3'], 0);
      expect(context['p4'], 61453);
      expect(context['p5'].isNaN, true);
      expect(context['f1'], 12.5);
      expect(context['f2'], -0.75);
      expect(context['f3'].isNaN, true);
      expect(context['n1'], true);
      expect(context['n2'], false);
      expect(context['n3'], false);
      expect(context['finite1'], true);
      expect(context['finite2'], true);
      expect(context['finite3'], false);
    });

    test('string indexing helpers follow practical ES5 bounds behavior', () {
      final context = <String, dynamic>{};
      evalJs('''
        var s = 'abcdef';
        var c1 = s.charAt(2);
        var c2 = s.charAt(99);
        var code1 = s.charCodeAt(1);
        var code2 = s.charCodeAt(99);
        var sub1 = s.substring(4, 2);
        var sub2 = s.substring(-2, 3);
        var sub3 = s.substring(3);
        var substr1 = s.substr(-2);
        var substr2 = s.substr(1, 3);
        var substr3 = s.substr(2, -1);
      ''', context);
      expect(context['c1'], 'c');
      expect(context['c2'], '');
      expect(context['code1'], 98);
      expect(context['code2'].isNaN, true);
      expect(context['sub1'], 'cd');
      expect(context['sub2'], 'abc');
      expect(context['sub3'], 'def');
      expect(context['substr1'], 'ef');
      expect(context['substr2'], 'bcd');
      expect(context['substr3'], '');
    });
  });

  group('Practical ES5 functions and objects', () {
    test('IIFE and function expression calls return values', () {
      final context = <String, dynamic>{};
      evalJs('''
        var a = (function(x) { return x + 1; })(4);
        var b = (function() { var secret = 'ok'; return secret; })();
      ''', context);
      expect(context['a'], 5);
      expect(context['b'], 'ok');
    });

    test('method calls bind this to receiver', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {
          value: 10,
          increment: function() { this.value++; return this.value; }
        };
        var result = obj.increment();
      ''', context);
      expect(context['obj']['value'], 11);
      expect(context['result'], 11);
    });

    test('Function call apply and bind set this and arguments', () {
      final context = <String, dynamic>{};
      evalJs('''
        function add(a, b) {
          return this.base + a + b;
        }
        var ctx = { base: 10 };
        var viaCall = add.call(ctx, 1, 2);
        var viaApply = add.apply(ctx, [3, 4]);
        var bound = add.bind(ctx, 5);
        var viaBind = bound(6);
      ''', context);
      expect(context['viaCall'], 13);
      expect(context['viaApply'], 17);
      expect(context['viaBind'], 21);
    });

    test('Dart callbacks work with call apply and bind arguments', () {
      final context = <String, dynamic>{
        'joinArgs': (dynamic a, dynamic b, dynamic c) => '$a:$b:$c',
      };
      evalJs('''
        var viaCall = joinArgs.call(null, 'a', 'b', 'c');
        var viaApply = joinArgs.apply(null, ['d', 'e', 'f']);
        var bound = joinArgs.bind(null, 'g');
        var viaBind = bound('h', 'i');
      ''', context);
      expect(context['viaCall'], 'a:b:c');
      expect(context['viaApply'], 'd:e:f');
      expect(context['viaBind'], 'g:h:i');
    });

    test('arguments object exposes indexes and length', () {
      final context = <String, dynamic>{};
      evalJs('''
        function pick() {
          return arguments[0] + ':' + arguments.length;
        }
        var result = pick('x', 'y', 'z');
      ''', context);
      expect(context['result'], 'x:3');
    });

    test('arguments callee refers to the executing function', () {
      final context = <String, dynamic>{};
      evalJs('''
        function factorial(n) {
          if (n <= 1) return 1;
          return n * arguments.callee(n - 1);
        }
        var result = factorial(5);
      ''', context);
      expect(context['result'], 120);
    });

    test('plain nested calls use global this while method calls use receiver',
        () {
      final context = <String, dynamic>{'marker': 'global'};
      evalJs('''
        var obj = {
          marker: 'object',
          method: function() {
            function nested() { return this.marker; }
            return nested();
          },
          direct: function() { return this.marker; }
        };
        var nestedResult = obj.method();
        var directResult = obj.direct();
      ''', context);
      expect(context['nestedResult'], 'global');
      expect(context['directResult'], 'object');
    });

    test('constructor calls create prototype-backed objects', () {
      final context = <String, dynamic>{};
      evalJs('''
        function Person(name) {
          this.name = name;
        }
        Person.prototype.greet = function() {
          return 'hi ' + this.name;
        };
        var p = new Person('Ada');
        var result = p.greet();
        var ok = p instanceof Person;
      ''', context);
      expect(context['result'], 'hi Ada');
      expect(context['ok'], true);
    });

    test('constructor returned objects override the created instance', () {
      final context = <String, dynamic>{};
      evalJs('''
        function Factory(name) {
          this.name = name;
          return { name: 'override', fromFactory: true };
        }
        var result = new Factory('created');
        var name = result.name;
        var flag = result.fromFactory;
      ''', context);
      expect(context['name'], 'override');
      expect(context['flag'], true);
    });

    test('object accessors and defineProperty work practically', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {
          value: 2,
          get doubled() { return this.value * 2; },
          set doubled(v) { this.value = v / 2; }
        };
        var a = obj.doubled;
        obj.doubled = 10;
        Object.defineProperty(obj, 'hidden', { value: 42, enumerable: false });
        var keys = Object.keys(obj).join(',');
      ''', context);
      expect(context['a'], 4);
      expect(context['obj']['value'], 5);
      expect(context['obj']['hidden'], 42);
      expect(context['keys'], 'value,doubled');
    });

    test('delete removes object properties but leaves array length intact', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = { a: 1 };
        var arr = [1, 2, 3];
        var d1 = delete obj.a;
        var d2 = delete arr[1];
        var hasA = 'a' in obj;
        var hasIndex = 1 in arr;
        var len = arr.length;
        var middle = arr[1];
        var seen = 0;
        arr.forEach(function() { seen++; });
        var json = JSON.stringify(arr);
      ''', context);
      expect(context['d1'], true);
      expect(context['d2'], true);
      expect(context['hasA'], false);
      expect(context['hasIndex'], false);
      expect(context['len'], 3);
      expect(context['middle'], isNull);
      expect(context['seen'], 2);
      expect(context['json'], '[1,null,3]');
    });

    test('array map skips holes but preserves sparse positions', () {
      final context = <String, dynamic>{};
      evalJs('''
        var arr = [1, 2, 3];
        delete arr[1];
        var mapped = arr.map(function(v) { return v * 10; });
        var called = 0;
        mapped.forEach(function() { called++; });
        var hasMiddle = 1 in mapped;
        var json = JSON.stringify(mapped);
      ''', context);
      expect(context['called'], 2);
      expect(context['hasMiddle'], false);
      expect(context['json'], '[10,null,30]');
    });

    test('array callbacks skip holes and receive indexes', () {
      final context = <String, dynamic>{};
      evalJs('''
        var arr = [2, 4, 6, 8];
        delete arr[1];
        var visited = [];
        var filtered = arr.filter(function(value, index) {
          visited.push(index + ':' + value);
          return index > 1;
        });
        var reduced = arr.reduce(function(total, value, index) {
          return total + index + value;
        }, 0);
        var some = arr.some(function(value, index) {
          return index === 2 && value === 6;
        });
        var every = arr.every(function(value, index) {
          return index !== 1 && value > 0;
        });
      ''', context);
      expect(context['visited'], ['0:2', '2:6', '3:8']);
      expect(context['filtered'], [6, 8]);
      expect(context['reduced'], 21);
      expect(context['some'], true);
      expect(context['every'], true);
    });

    test('array search methods keep original sparse indexes', () {
      final context = <String, dynamic>{};
      evalJs('''
        var arr = ['a', 'b', 'c', 'd'];
        delete arr[1];
        var found = arr.find(function(value, index) {
          return index === 2 && value === 'c';
        });
        var foundIndex = arr.findIndex(function(value, index) {
          return index === 2 && value === 'c';
        });
        var index = arr.indexOf('c');
        var lastIndex = arr.lastIndexOf('c');
        var missing = arr.indexOf('b');
      ''', context);
      expect(context['found'], 'c');
      expect(context['foundIndex'], 2);
      expect(context['index'], 2);
      expect(context['lastIndex'], 2);
      expect(context['missing'], -1);
    });

    test('array iterators preserve sparse indexes and visible values', () {
      final context = <String, dynamic>{};
      evalJs('''
        var arr = ['a', 'b', 'c'];
        delete arr[1];
        arr[5] = 'f';
        var keys = arr.keys().join(',');
        var valuesJson = JSON.stringify(arr.values());
        var entriesJson = JSON.stringify(arr.entries());
        var len = arr.length;
        var hasFour = 4 in arr;
      ''', context);
      expect(context['keys'], '0,1,2,3,4,5');
      expect(context['valuesJson'], '["a",null,"c",null,null,"f"]');
      expect(context['entriesJson'],
          '[{"key":0,"value":"a"},{"key":1,"value":null},{"key":2,"value":"c"},{"key":3,"value":null},{"key":4,"value":null},{"key":5,"value":"f"}]');
      expect(context['len'], 6);
      expect(context['hasFour'], false);
    });

    test('array slice reverse splice and copyWithin preserve holes practically',
        () {
      final context = <String, dynamic>{};
      evalJs('''
        var arr = [1, 2, 3, 4];
        delete arr[1];
        var sliced = arr.slice(0, 3);
        var reversed = arr.reverse();
        var reversedBeforeSpliceJson = JSON.stringify(reversed);
        var removed = arr.splice(1, 2, 9);

        var copy = ['a', 'b', 'c', 'd'];
        delete copy[1];
        copy.copyWithin(2, 0, 2);

        var slicedJson = JSON.stringify(sliced);
        var reversedAfterSpliceJson = JSON.stringify(reversed);
        var removedJson = JSON.stringify(removed);
        var arrJson = JSON.stringify(arr);
        var copyJson = JSON.stringify(copy);
      ''', context);
      expect(context['slicedJson'], '[1,null,3]');
      expect(context['reversedBeforeSpliceJson'], '[4,3,null,1]');
      expect(context['reversedAfterSpliceJson'], '[4,9,1]');
      expect(context['removedJson'], '[3,null]');
      expect(context['arrJson'], '[4,9,1]');
      expect(context['copyJson'], '["a",null,"a",null]');
    });

    test('array negative indexes and optional bounds are normalized', () {
      final context = <String, dynamic>{};
      evalJs('''
        var arr = [1, 2, 3, 2, 5];
        var atLast = arr.at(-1);
        var indexFromNegative = arr.indexOf(2, -2);
        var lastIndexBounded = arr.lastIndexOf(2, 2);
        var sliced = arr.slice(-3, -1);
        var fillTarget = [1, 2, 3, 4];
        fillTarget.fill(9, -2);
        var spliceTarget = [1, 2, 3, 4, 5];
        var removed = spliceTarget.splice(-2, 1, 8, 9);
        var spliceNullTarget = [1, 2];
        spliceNullTarget.splice(1, 0, null);
        var slicedJson = JSON.stringify(sliced);
        var filledJson = JSON.stringify(fillTarget);
        var removedJson = JSON.stringify(removed);
        var splicedJson = JSON.stringify(spliceTarget);
        var splicedNullJson = JSON.stringify(spliceNullTarget);
      ''', context);
      expect(context['atLast'], 5);
      expect(context['indexFromNegative'], 3);
      expect(context['lastIndexBounded'], 1);
      expect(context['slicedJson'], '[3,2]');
      expect(context['filledJson'], '[1,2,9,9]');
      expect(context['removedJson'], '[4]');
      expect(context['splicedJson'], '[1,2,3,8,9,5]');
      expect(context['splicedNullJson'], '[1,null,2]');
    });

    test('array indexes work through string property names', () {
      final context = <String, dynamic>{};
      evalJs('''
        var arr = [4, 5, 6];
        var before = '1' in arr;
        var value = arr['1'];
        delete arr['1'];
        var after = '1' in arr;
      ''', context);
      expect(context['before'], true);
      expect(context['value'], 5);
      expect(context['after'], false);
    });

    test('null descriptors keep their value field', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {};
        Object.defineProperty(obj, 'x', { value: null, enumerable: true });
        var desc = Object.getOwnPropertyDescriptor(obj, 'x');
        var hasValue = 'value' in desc;
        var val = desc.value;
      ''', context);
      expect(context['hasValue'], true);
      expect(context['val'], isNull);
    });

    test('plain object properties expose default descriptors', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = { a: 1 };
        var desc = Object.getOwnPropertyDescriptor(obj, 'a');
        var missing = Object.getOwnPropertyDescriptor(obj, 'missing');
        var hasValue = 'value' in desc;
        var value = desc.value;
        var enumerable = desc.enumerable;
        var writable = desc.writable;
        var configurable = desc.configurable;
      ''', context);
      expect(context['hasValue'], true);
      expect(context['value'], 1);
      expect(context['enumerable'], true);
      expect(context['writable'], true);
      expect(context['configurable'], true);
      expect(context['missing'], isNull);
    });

    test('accessor descriptors do not invent a value field', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {};
        Object.defineProperty(obj, 'x', {
          get: function() { return 7; },
          enumerable: true
        });
        var desc = Object.getOwnPropertyDescriptor(obj, 'x');
        var hasValue = 'value' in desc;
        var value = obj.x;
      ''', context);
      expect(context['hasValue'], false);
      expect(context['value'], 7);
    });

    test('Object assign copies only enumerable own values', () {
      final context = <String, dynamic>{};
      evalJs('''
        var proto = { inherited: 1 };
        var source = Object.create(proto);
        source.visible = 2;
        Object.defineProperty(source, 'hidden', { value: 3, enumerable: false });
        Object.defineProperty(source, 'computed', {
          get: function() { return 4; },
          enumerable: true
        });
        var target = {};
        Object.assign(target, source);
        var keys = Object.keys(target).sort().join(',');
        var visible = target.visible;
        var computed = target.computed;
        var hasHidden = 'hidden' in target;
        var hasInherited = 'inherited' in target;
      ''', context);
      expect(context['keys'], 'computed,visible');
      expect(context['visible'], 2);
      expect(context['computed'], 4);
      expect(context['hasHidden'], false);
      expect(context['hasInherited'], false);
    });

    test('descriptor writable and configurable flags are honored', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {};
        Object.defineProperty(obj, 'fixed', {
          value: 1,
          writable: false,
          configurable: false,
          enumerable: true
        });
        obj.fixed = 2;
        var deleted = delete obj.fixed;
        var value = obj.fixed;
        var keys = Object.keys(obj).join(',');
      ''', context);
      expect(context['deleted'], false);
      expect(context['value'], 1);
      expect(context['keys'], 'fixed');
    });

    test('descriptor redefinition preserves omitted flags', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {};
        Object.defineProperty(obj, 'x', {
          value: 1,
          writable: true,
          enumerable: true,
          configurable: true
        });
        Object.defineProperty(obj, 'x', { value: 2 });
        var desc = Object.getOwnPropertyDescriptor(obj, 'x');
        var keys = Object.keys(obj).join(',');
        var value = obj.x;
        obj.x = 3;
        var written = obj.x;
      ''', context);
      expect(context['value'], 2);
      expect(context['written'], 3);
      expect(context['keys'], 'x');
      expect(context['desc']['enumerable'], true);
      expect(context['desc']['writable'], true);
      expect(context['desc']['configurable'], true);
    });

    test('delete reports success for existing null-valued properties', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = { a: null };
        var before = obj.hasOwnProperty('a');
        var deleted = delete obj.a;
        var after = obj.hasOwnProperty('a');
      ''', context);
      expect(context['before'], true);
      expect(context['deleted'], true);
      expect(context['after'], false);
    });

    test('hasOwnProperty and propertyIsEnumerable use descriptors', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {};
        Object.defineProperty(obj, 'hidden', { value: 1, enumerable: false });
        Object.defineProperty(obj, 'shown', { value: 2, enumerable: true });
        var ownHidden = obj.hasOwnProperty('hidden');
        var enumHidden = obj.propertyIsEnumerable('hidden');
        var enumShown = obj.propertyIsEnumerable('shown');
        var staticEnumShown = Object.propertyIsEnumerable(obj, 'shown');
      ''', context);
      expect(context['ownHidden'], true);
      expect(context['enumHidden'], false);
      expect(context['enumShown'], true);
      expect(context['staticEnumShown'], true);
    });

    test('JSON stringify uses enumerable properties and accessors', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = { a: 1 };
        Object.defineProperty(obj, 'hidden', { value: 2, enumerable: false });
        Object.defineProperty(obj, 'computed', {
          get: function() { return 3; },
          enumerable: true
        });
        var json = JSON.stringify(obj);
      ''', context);
      expect(context['json'], '{"a":1,"computed":3}');
    });

    test('JSON stringify rejects circular structures without recursing forever',
        () {
      expect(
        () => evalJs('''
          var obj = {};
          obj.self = obj;
          JSON.stringify(obj);
        '''),
        throwsA(isA<JSException>()),
      );
    });

    test('sparse array expansion has a practical safety limit', () {
      expect(
        () => evalJs('''
          var arr = [];
          arr[1000001] = 'too large';
        '''),
        throwsA(isA<JSException>()),
      );
    });
  });

  group('Practical ES5 confidence and boundary markers', () {
    test(
        'defineProperty defaults are non-writable non-enumerable non-configurable',
        () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = {};
        Object.defineProperty(obj, 'locked', { value: 7 });
        var desc = Object.getOwnPropertyDescriptor(obj, 'locked');
        obj.locked = 9;
        var deleteResult = delete obj.locked;
        var visibleKeys = Object.keys(obj).join(',');
        var value = obj.locked;
      ''', context);
      expect(context['value'], 7);
      expect(context['deleteResult'], false);
      expect(context['visibleKeys'], '');
      expect(context['desc']['writable'], false);
      expect(context['desc']['enumerable'], false);
      expect(context['desc']['configurable'], false);
    });

    test('inherited properties are visible through in but not Object.keys', () {
      final context = <String, dynamic>{};
      evalJs('''
        var proto = {};
        Object.defineProperty(proto, 'inherited', {
          value: 3,
          enumerable: true
        });
        var obj = Object.create(proto);
        obj.own = 4;
        var hasInherited = 'inherited' in obj;
        var hasOwnInherited = obj.hasOwnProperty('inherited');
        var ownKeys = Object.keys(obj).join(',');
        var forInKeys = [];
        for (var key in obj) {
          forInKeys.push(key);
        }
        var enumerated = forInKeys.sort().join(',');
      ''', context);
      expect(context['hasInherited'], true);
      expect(context['hasOwnInherited'], false);
      expect(context['ownKeys'], 'own');
      expect(context['enumerated'], 'inherited,own');
    });

    test('with statement has practical object-scope support', () {
      final context = <String, dynamic>{};
      evalJs('''
        var obj = { a: 1 };
        var type = '';
        with (obj) {
          a = 3;
          type = typeof a;
        }
      ''', context);
      expect(context['obj']['a'], 3);
      expect(context['type'], 'number');
    });

    test('with object properties shadow outer lexical names', () {
      final context = <String, dynamic>{};
      evalJs('''
        var a = 1;
        var obj = { a: 2 };
        var result;
        with (obj) {
          result = a;
        }
      ''', context);
      expect(context['result'], 2);
    });

    test('Object.create links prototype properties', () {
      final context = <String, dynamic>{};
      evalJs('''
        var proto = { inherited: 9 };
        var obj = Object.create(proto);
        var value = obj.inherited;
        var hasValue = 'inherited' in obj;
        var keys = Object.keys(obj).join(',');
        var sameProto = Object.getPrototypeOf(obj) === proto;
        var isProto = Object.isPrototypeOf(proto, obj);
      ''', context);
      expect(context['value'], 9);
      expect(context['hasValue'], true);
      expect(context['keys'], '');
      expect(context['sameProto'], true);
      expect(context['isProto'], true);
    });

    test('for in sees enumerable descriptor and prototype keys', () {
      final context = <String, dynamic>{};
      evalJs('''
        function Holder() {}
        Holder.prototype.inherited = 1;
        var obj = new Holder();
        Object.defineProperty(obj, 'own', { value: 2, enumerable: true });
        var keys = [];
        for (var key in obj) {
          keys.push(key);
        }
        var result = keys.sort().join(',');
      ''', context);
      expect(context['result'], 'inherited,own');
    });

    test('break outside loop still fails', () {
      expect(
        () => evalJs('break;'),
        throwsA(isA<JSException>()),
      );
    });

    test(
      'strict mode semantics are intentionally outside the practical ES5 contract',
      () {
        evalJs('''
          'use strict';
          undeclaredStrictWrite = 1;
        ''');
      },
      skip:
          'Strict mode parsing may work, but strict-mode runtime semantics are not supported yet.',
    );

    test(
      'direct eval is intentionally outside the practical ES5 contract',
      () {
        final context = <String, dynamic>{};
        evalJs('''
          eval('var createdByEval = 5;');
        ''', context);
        expect(context['createdByEval'], 5);
      },
      skip: 'Direct eval scope semantics are not supported yet.',
    );

    test(
      'ES6 declarations remain outside the ES5 compatibility contract',
      () {
        final context = <String, dynamic>{};
        evalJs('''
          let x = 1;
          const y = 2;
          var result = x + y;
        ''', context);
        expect(context['result'], 3);
      },
      skip: 'let/const/block scoping are part of the future ES6+ track.',
    );
  });
}
