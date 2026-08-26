import 'package:ensemble/action/dialog_actions.dart';
import 'package:ensemble/action/navigation_action.dart';
import 'package:ensemble/framework/action.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

void main() {
  test('unmarshal action', () {
    const navigateBackMatcher = TypeMatcher<NavigateBackAction>();
    expect(EnsembleAction.from('navigateBack'), navigateBackMatcher);
    expect(EnsembleAction.from(YamlMap.wrap({'navigateBack': {}})),
        navigateBackMatcher);
    expect(EnsembleAction.from(YamlMap.wrap({'navigateBack': null})),
        navigateBackMatcher);

    const closeAllDialogsMatcher = TypeMatcher<CloseAllDialogsAction>();
    expect(EnsembleAction.from('closeAllDialogs'), closeAllDialogsMatcher);
    expect(EnsembleAction.from(YamlMap.wrap({'closeAllDialogs': {}})),
        closeAllDialogsMatcher);
  });

  group('navigateScreen stack parsing', () {
    test('distinguishes omitted and empty stacks', () {
      final omitted = NavigateScreenAction.fromMap(
          payload: <String, dynamic>{'name': 'System'});
      final empty = NavigateScreenAction.fromMap(
          payload: <String, dynamic>{'name': 'System', 'stack': <dynamic>[]});

      expect(omitted.stack, isNull);
      expect(empty.stack, isEmpty);
    });

    test('parses object entries with unevaluated names and inputs', () {
      final action = NavigateScreenAction.fromMap(payload: <String, dynamic>{
        'name': 'System',
        'stack': <dynamic>[
          <String, dynamic>{'name': 'Home'},
          <String, dynamic>{
            'name': r'${parentScreen}',
            'inputs': <String, dynamic>{'section': r'${section}'}
          },
        ],
      });

      expect(action.stack, hasLength(2));
      expect(action.stack![1].name, r'${parentScreen}');
      expect(action.stack![1].inputs!['section'], r'${section}');
    });

    test('rejects the ticket string-only format', () {
      expect(
        () => NavigateScreenAction.fromMap(payload: <String, dynamic>{
          'name': 'System',
          'stack': <dynamic>['Home']
        }),
        throwsA(isA<LanguageError>()),
      );
    });

    test('rejects missing names and non-map inputs', () {
      expect(
        () => NavigateScreenAction.fromMap(payload: <String, dynamic>{
          'name': 'System',
          'stack': <dynamic>[
            <String, dynamic>{'inputs': <String, dynamic>{}}
          ]
        }),
        throwsA(isA<LanguageError>()),
      );
      expect(
        () => NavigateScreenAction.fromMap(payload: <String, dynamic>{
          'name': 'System',
          'stack': <dynamic>[
            <String, dynamic>{'name': 'Home', 'inputs': 'invalid'}
          ]
        }),
        throwsA(isA<LanguageError>()),
      );
    });

    test('rejects imperative stack options and external navigator', () {
      for (final payload in <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'System',
          'stack': <dynamic>[],
          'options': <String, dynamic>{'clearAllScreens': true},
        },
        <String, dynamic>{
          'name': 'System',
          'stack': <dynamic>[],
          'options': <String, dynamic>{'replaceCurrentScreen': true},
        },
        <String, dynamic>{
          'name': 'System',
          'stack': <dynamic>[],
          'asExternal': true,
        },
      ]) {
        expect(
          () => NavigateScreenAction.fromMap(payload: payload),
          throwsA(isA<LanguageError>()),
        );
      }
    });
  });
}
