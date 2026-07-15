import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:ensemble_ts_interpreter/invokables/context.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/foundation.dart';
import 'package:test/test.dart';

dynamic evalJs(String code, [Map<String, dynamic>? context]) {
  final ctx = context ?? <String, dynamic>{};
  return JSInterpreter.fromCode(code, SimpleContext(ctx)).evaluate();
}

void main() {
  group('ES6 compatibility', () {
    test('let is block scoped and can shadow outer bindings', () {
      final context = <String, dynamic>{};
      evalJs('''
        var outer = 1;
        {
          let outer = 2;
          var inner = outer;
        }
        var result = outer + ':' + inner;
      ''', context);
      expect(context['result'], '1:2');
    });

    test('let closures capture block bindings', () {
      final context = <String, dynamic>{};
      evalJs('''
        var fn;
        {
          let value = 7;
          fn = function() { return value; };
        }
        var result = fn();
      ''', context);
      expect(context['result'], 7);
    });

    test('let in for loop creates per-iteration closure bindings', () {
      final context = <String, dynamic>{};
      evalJs('''
        var fns = [];
        for (let i = 0; i < 3; i++) {
          fns.push(function() { return i; });
        }
        var result = fns[0]() + ',' + fns[1]() + ',' + fns[2]();
      ''', context);
      expect(context['result'], '0,1,2');
    });

    test('read before lexical initialization throws a JSException', () {
      expect(
        () => evalJs('''
          {
            var result = value;
            let value = 1;
          }
        '''),
        throwsA(isA<JSException>()),
      );
    });

    test('const can hold mutable objects but cannot be reassigned', () {
      final context = <String, dynamic>{};
      evalJs('''
        const obj = { count: 1 };
        obj.count = 2;
        var result = obj.count;
      ''', context);
      expect(context['result'], 2);

      expect(
        () => evalJs('''
          const locked = 1;
          locked = 2;
        '''),
        throwsA(isA<JSException>()),
      );
    });

    test('template literals interpolate expressions in order', () {
      final context = <String, dynamic>{};
      evalJs(r'''
        var count = 0;
        function next() {
          count++;
          return count;
        }
        var result = `first ${next()} second ${next()}`;
      ''', context);
      expect(context['result'], 'first 1 second 2');
    });

    test('template literals support multiline text and escaped backticks', () {
      final context = <String, dynamic>{};
      evalJs(r'''
        var result = `a
b \`c\``;
      ''', context);
      expect(context['result'], 'a\nb `c`');
    });

    test('tagged templates call tag with strings and values', () {
      final context = <String, dynamic>{};
      evalJs(r'''
        function currency(strings, ...values) {
          return strings.reduce((result, str, i) => {
            const value = values[i] !== undefined
              ? `$${values[i].toFixed(2)}`
              : "";

            return result + str + value;
          }, "");
        }

        const price = 99.99;
        var result = currency`Price: ${price}`;
      ''', context);
      expect(context['result'], r'Price: $99.99');
    });

    test('array out-of-range reads return undefined', () {
      final context = <String, dynamic>{};
      evalJs(r'''
        var values = [1];
        var result = [
          values[1] === undefined,
          values[1] == null,
          typeof values[1]
        ].join('|');
      ''', context);
      expect(context['result'], 'true|true|undefined');
    });

    test('default and rest parameters work for normal functions', () {
      final context = <String, dynamic>{};
      evalJs('''
        function join(prefix = 'x', ...items) {
          return prefix + ':' + items.join(',');
        }
        var result = join(null, 1, 2, 3);
      ''', context);
      expect(context['result'], 'x:1,2,3');
    });

    test('rest parameters can be reduced with arrow callbacks', () {
      final context = <String, dynamic>{};
      evalJs('''
        function sum(...numbers) {
          return numbers.reduce((total, num) => total + num, 0);
        }
        var result = sum(1, 2, 3, 4);
      ''', context);
      expect(context['result'], 10);
    });

    test('default and rest parameters work for arrow functions', () {
      final context = <String, dynamic>{};
      evalJs('''
        var fn = (prefix = 'x', ...items) => prefix + ':' + items.length;
        var result = fn(null, 1, 2);
      ''', context);
      expect(context['result'], 'x:2');
    });

    test('spread expands lists in array literals and calls', () {
      final context = <String, dynamic>{
        'fromDart': [3, 4]
      };
      evalJs('''
        function sum(a, b, c, d) {
          return a + b + c + d;
        }
        var values = [1, 2, ...fromDart];
        var result = sum(...values);
      ''', context);
      expect(context['result'], 10);
    });

    test('for of iterates arrays, rest parameters, and strings', () {
      final context = <String, dynamic>{};
      evalJs('''
        function sum(...numbers) {
          let total = 0;
          for (let n of numbers) {
            total += n;
          }
          return total;
        }
        let letters = '';
        for (const ch of 'abc') {
          letters += ch;
        }
        var result = sum(1, 2, 3) + ':' + letters;
      ''', context);
      expect(context['result'], '6:abc');
    });

    test('for of lexical declarations capture per-iteration values', () {
      final context = <String, dynamic>{};
      evalJs('''
        var fns = [];
        for (const value of [1, 2, 3]) {
          fns.push(function() { return value; });
        }
        var result = fns[0]() + ',' + fns[1]() + ',' + fns[2]();
      ''', context);
      expect(context['result'], '1,2,3');
    });

    test('for of iterates Set values and Map entries', () {
      final context = <String, dynamic>{};
      evalJs('''
        var set = new Set([1, 2, 3]);
        var total = 0;
        for (let value of set) {
          total += value;
        }

        var map = new Map();
        map.set('a', 1);
        map.set('b', 2);
        var pairs = [];
        for (let entry of map) {
          pairs.push(entry.key + entry.value);
        }

        var result = total + ':' + pairs.join(',');
      ''', context);
      expect(context['result'], '6:a1,b2');
    });

    test('existing ES6 conveniences remain available', () {
      final context = <String, dynamic>{};
      evalJs('''
        var doubled = [1, 2, 3].map((value) => value * 2).join(',');
        var map = new Map();
        map.set('a', 1);
        var set = new Set();
        set.add(2);
        var result = doubled + ':' + map.get('a') + ':' + set.has(2);
      ''', context);
      expect(context['result'], '2,4,6:1:true');
    });

    test('console formats Set and Map values readably', () {
      final logs = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        evalJs('''
          const numbers = new Set([1, 2, 2, 3, 4]);
          console.log("Numbers:", numbers);

          const labels = new Map();
          labels.set("one", 1);
          console.log("Labels:", labels);
        ''');
      } finally {
        debugPrint = oldDebugPrint;
      }

      expect(logs, contains('Numbers: Set(4) {1, 2, 3, 4}'));
      expect(logs, contains('Labels: Map(1) {"one" => 1}'));
    });

    test('nullish coalescing only falls back for nullish values', () {
      final context = <String, dynamic>{};
      evalJs('''
        var fromNull = null ?? 'fallback';
        var fromMissing = missing ?? 'fallback';
        var fromFalse = false ?? true;
        var fromZero = 0 ?? 99;
        var fromEmpty = '' ?? 'fallback';
        var result = [fromNull, fromMissing, fromFalse, fromZero, fromEmpty].join('|');
      ''', context);

      expect(context['result'], 'fallback|fallback|false|0|');
    });

    test('optional chaining short-circuits property and index access', () {
      final context = <String, dynamic>{};
      evalJs('''
        var calls = 0;
        function key() {
          calls++;
          return 'name';
        }

        var user = { profile: { name: 'Ada' } };
        var first = user?.profile?.name;
        var second = user?.missing?.name ?? 'Guest';
        var third = null?.profile?.name ?? 'Guest';
        var skipped = null?.[key()];
        var called = user.profile?.[key()];
        var result = [first, second, third, skipped, called, calls].join('|');
      ''', context);

      expect(context['result'], 'Ada|Guest|Guest|undefined|Ada|1');
    });

    test('optional chaining returns undefined instead of null', () {
      final context = <String, dynamic>{};
      evalJs('''
        const person = {
          address: {
            city: 'London'
          }
        };

        var missing = person.company?.name;
        var result = [
          person.address?.city,
          typeof missing,
          missing == null,
          missing === null,
          missing ?? 'fallback',
          !!missing
        ].join('|');
      ''', context);

      expect(context['result'], 'London|undefined|true|false|fallback|false');
    });

    test('console distinguishes optional-chain undefined from null', () {
      final logs = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        evalJs('''
          const person = {
            address: {
              city: 'London'
            }
          };

          console.log(person.address?.city);
          console.log(person.company?.name);
          console.log(null);
        ''');
      } finally {
        debugPrint = oldDebugPrint;
      }

      expect(logs, contains('London'));
      expect(logs, contains('undefined'));
      expect(logs, contains('null'));
    });

    test('optional chaining short-circuits calls', () {
      final context = <String, dynamic>{};
      evalJs('''
        var calls = 0;
        function next() {
          calls++;
          return 'called';
        }
        var obj = {
          run: function(value) {
            return value + ':' + this.prefix;
          },
          prefix: 'ok'
        };

        var missingFn = null;
        var first = missingFn?.(next()) ?? 'skipped';
        var second = null?.run(next()) ?? 'skipped';
        var third = obj.run?.('yes');
        var result = [first, second, third, calls].join('|');
      ''', context);

      expect(context['result'], 'skipped|skipped|yes:ok|0');
    });

    test('single-parameter arrow functions do not require parentheses', () {
      final context = <String, dynamic>{};
      evalJs('''
        const square = num => num * num;
        var result = square(4);
      ''', context);

      expect(context['result'], 16);
    });

    test('object and array destructuring declarations bind values', () {
      final context = <String, dynamic>{};
      evalJs('''
        const person = {
          name: 'John',
          age: 30,
          address: {
            city: 'London'
          }
        };
        const { name, age, address: { city } } = person;
        const [first, , third, ...rest] = [1, 2, 3, 4, 5];
        var result = [name, age, city, first, third, rest.join(',')].join('|');
      ''', context);

      expect(context['result'], 'John|30|London|1|3|4,5');
    });

    test('object shorthand, enhanced methods, and computed keys work', () {
      final context = <String, dynamic>{};
      evalJs('''
        const email = 'john@example.com';
        const key = 'email';
        const user = {
          email,
          [key + 'Verified']: true
        };
        const calculator = {
          add(a, b) {
            return a + b;
          }
        };
        var result = [
          user.email,
          user.emailVerified,
          calculator.add(2, 3)
        ].join('|');
      ''', context);

      expect(context['result'], 'john@example.com|true|5');
    });

    test('Promise then callbacks run with arrow functions', () async {
      final logs = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        evalJs('''
          const promise = new Promise((resolve, reject) => {
            resolve('Success');
          });

          promise.then(result => console.log(result));
        ''');
        await Future<void>.delayed(Duration.zero);
      } finally {
        debugPrint = oldDebugPrint;
      }

      expect(logs, contains('Success'));
    });

    test('Symbol values can be used as computed object keys', () {
      final context = <String, dynamic>{};
      evalJs('''
        const id = Symbol('id');
        const user = {
          [id]: 101
        };
        var result = user[id];
      ''', context);

      expect(context['result'], 101);
    });

    test('async functions await promises and return promises', () async {
      final logs = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        evalJs('''
          async function loadMessage() {
            const value = await Promise.resolve('Success');
            return `Result: \${value}`;
          }

          loadMessage().then(result => console.log(result));
        ''');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      } finally {
        debugPrint = oldDebugPrint;
      }

      expect(logs, contains('Result: Success'));
    });

    test('async arrows await plain values and resolved promises', () async {
      final context = <String, dynamic>{};
      evalJs('''
        const doubleLater = async value => {
          const base = await value;
          const extra = await Promise.resolve(2);
          return base * extra;
        };

        doubleLater(4).then(result => {
          asyncResult = result;
        });
      ''', context);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(context['asyncResult'], 8);
    });

    test('async functions reject when awaited promises reject', () async {
      final context = <String, dynamic>{};
      evalJs('''
        async function failLater() {
          return await Promise.reject('Nope');
        }

        failLater().catch(error => {
          asyncError = error;
        });
      ''', context);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(context['asyncError'], 'Nope');
    });

    test('promise callbacks can use console methods directly', () async {
      final logs = <String>[];
      final oldDebugPrint = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) logs.add(message);
      };
      try {
        evalJs('''
          const fetchData = async () => {
            return 'Data Loaded';
          };

          fetchData().then(console.log);
        ''');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      } finally {
        debugPrint = oldDebugPrint;
      }

      expect(logs, contains('Data Loaded'));
    });

    test('destructuring parameters and assignment work for practical patterns',
        () {
      final context = <String, dynamic>{};
      evalJs(r'''
        const displayUser = ({ name, age }) => `${name}:${age}`;
        let a = 10;
        let b = 20;
        [a, b] = [b, a];
        var result = [displayUser({ name: 'Sara', age: 22 }), a, b].join('|');
      ''', context);

      expect(context['result'], 'Sara:22|20|10');
    });

    test('object spread copies enumerable own properties', () {
      final context = <String, dynamic>{};
      evalJs('''
        const person = {
          name: 'Ali',
          age: 20
        };
        const updatedPerson = {
          ...person,
          city: 'Lahore'
        };
        var result = [
          updatedPerson.name,
          updatedPerson.age,
          updatedPerson.city
        ].join('|');
      ''', context);

      expect(context['result'], 'Ali|20|Lahore');
    });

    test('Array from of and constructor helpers work', () {
      final context = <String, dynamic>{};
      evalJs('''
        const letters = Array.from('Hi').join(',');
        const numbers = Array.of(10, 20, 30).join(',');
        const filled = new Array(3).fill(0).join(',');
        var result = [letters, numbers, filled].join('|');
      ''', context);

      expect(context['result'], 'H,i|10,20,30|0,0,0');
    });

    test('Promise all and allSettled resolve practical results', () async {
      final context = <String, dynamic>{};
      evalJs('''
        const p1 = Promise.resolve(1);
        const p2 = Promise.resolve(2);
        Promise.all([p1, p2]).then(values => {
          allResult = values.join(',');
        });

        Promise.allSettled([
          Promise.resolve('Success'),
          Promise.reject('Error')
        ]).then(results => {
          settledResult = results.map(item => item.status).join(',');
          settledReason = results[1].reason;
        });
      ''', context);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(context['allResult'], '1,2');
      expect(context['settledResult'], 'fulfilled,rejected');
      expect(context['settledReason'], 'Error');
    });

    test('Array.from supports collections and array-like objects', () {
      final context = <String, dynamic>{};
      evalJs('''
        const setValues = Array.from(new Set([1, 2, 2, 3])).join(',');
        const map = new Map([['a', 1], ['b', 2]]);
        const mapValues = Array.from(map).map(entry => entry.key + entry.value).join(',');
        const arrayLike = Array.from({ 0: 'x', 1: 'y', length: 2 }).join('');
        const mapped = Array.from({ '0': 2, '1': 3, length: 2 }, value => value * 2).join(',');
        var result = [setValues, mapValues, arrayLike, mapped].join('|');
      ''', context);

      expect(context['result'], '1,2,3|a1,b2|xy|4,6');
    });

    test('Object modern helpers use practical own property semantics', () {
      final context = <String, dynamic>{};
      evalJs('''
        const source = { visible: 1 };
        Object.defineProperty(source, 'hidden', {
          value: 2,
          enumerable: false
        });
        const roundTrip = Object.fromEntries(Object.entries(source));
        const names = Object.getOwnPropertyNames(source).sort().join(',');
        var result = [
          roundTrip.visible,
          Object.hasOwn(source, 'visible'),
          Object.hasOwn(source, 'missing'),
          Object.keys(source).join(','),
          names
        ].join('|');
      ''', context);

      expect(context['result'], '1|true|false|visible|hidden,visible');
    });

    test('Promise race any and finally cover common paths', () async {
      final context = <String, dynamic>{};
      evalJs('''
        Promise.race([
          Promise.resolve('first'),
          Promise.resolve('second')
        ]).then(value => {
          raceResult = value;
        });

        Promise.any([
          Promise.reject('bad'),
          Promise.resolve('good')
        ]).then(value => {
          anyResult = value;
        });

        Promise.resolve('done')
          .finally(() => {
            finallyFulfilled = 'cleanup';
            return Promise.resolve('ignored');
          })
          .then(value => {
            finallyValue = value;
          });

        Promise.reject('nope')
          .finally(() => {
            finallyRejected = 'cleanup';
          })
          .catch(reason => {
            finallyReason = reason;
          });
      ''', context);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(context['raceResult'], 'first');
      expect(context['anyResult'], 'good');
      expect(context['finallyFulfilled'], 'cleanup');
      expect(context['finallyValue'], 'done');
      expect(context['finallyRejected'], 'cleanup');
      expect(context['finallyReason'], 'nope');
    });

    test('for of supports destructuring declarations and assignment targets',
        () {
      final context = <String, dynamic>{};
      evalJs('''
        const obj = { a: 1, b: 2 };
        const pairs = [];
        for (const [key, value] of Object.entries(obj)) {
          pairs.push(key + value);
        }

        const ids = [];
        for (const { id } of [{ id: 3 }, { id: 4 }]) {
          ids.push(id);
        }

        let assignedKey = '';
        let assignedValue = 0;
        for ([assignedKey, assignedValue] of [['z', 9]]) {}

        var result = [
          pairs.join(','),
          ids.join(','),
          assignedKey + assignedValue
        ].join('|');
      ''', context);

      expect(context['result'], 'a1,b2|3,4|z9');
    });

    test(
        'destructuring defaults and object rest work in declarations and params',
        () {
      final context = <String, dynamic>{};
      evalJs('''
        const user = { id: 7, city: 'Paris' };
        const { name = 'Guest', id, ...rest } = user;
        const [first = 'x', second = 'y'] = [undefined, 'b'];

        function label({ title = 'Untitled', ...details }) {
          return title + ':' + details.count;
        }

        var result = [
          name,
          id,
          rest.city,
          first,
          second,
          label({ count: 3 })
        ].join('|');
      ''', context);

      expect(context['result'], 'Guest|7|Paris|x|b|Untitled:3');
    });

    test('existing string collection and array helpers are covered', () {
      final context = <String, dynamic>{};
      evalJs('''
        const text = '  hi';
        const strings = [
          text.trimStart(),
          'x'.padStart(3, '0'),
          'x'.padEnd(3, '0')
        ].join(',');

        const set = new Set(['a', 'b']);
        const map = new Map([['k', 5]]);
        let collection = [
          set.keys().join(''),
          set.values().join(''),
          set.entries().map(entry => entry[0] + entry[1]).join(''),
          map.keys().join(''),
          map.values().join('')
        ].join('|');

        const nums = [1, 2, 3, 2];
        var result = [
          strings,
          collection,
          nums.findLast(value => value < 3),
          nums.findLastIndex(value => value < 3)
        ].join('|');
      ''', context);

      expect(context['result'], 'hi,00x,x00|ab|ab|aabb|k|5|2|3');
    });

    test('unsupported syntax parse errors use stable guidance', () {
      try {
        evalJs('''
          class Person {}
        ''');
        fail('Expected parser to reject classes.');
      } on JSException catch (e) {
        expect(e.message, contains('JavaScript parse error'));
        expect(e.recovery, contains('ES5 is the compatibility baseline'));
        expect(e.detailedError, contains('class Person {}'));
        expect(e.detailedError, contains('^'));
        expect(e.detailedError,
            isNot(contains('ES5 is the compatibility baseline')));
      }
    });

    test('classes remain outside ES6', () {}, skip: 'Deferred.');
    test('modules remain outside ES6', () {}, skip: 'Deferred.');
    test('generators remain outside ES6', () {}, skip: 'Deferred.');
  });
}
