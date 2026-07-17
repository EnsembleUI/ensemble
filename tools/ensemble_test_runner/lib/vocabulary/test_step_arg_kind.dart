/// Argument shape for a declarative test step (JSON Schema for editor validation).
enum TestStepArgKind {
  empty,
  openScreen,
  trigger,
  idRequired,
  idOptional,
  enterText,
  select,
  selectIndex,
  setSlider,
  chooseValue,
  scroll,
  swipe,
  drag,
  pump,
  timeoutOptional,
  httpRequest,
  runCommand,
  waitFor,
  waitForGone,
  waitForNavigation,
  textRequired,
  expectEquals,
  expectChecked,
  expectProperty,
  expectCount,
  expectListCount,
  screenRequired,
  expectVisited,
  apiName,
  storageKey,
  group,
  repeat,
  optional,
  ifVisible,
  setAuth,
  setPermission,
  setDevice,
  setLocale,
  setTheme,
  runScript,
  expectConsoleLog,
  expectErrorContains,
  expectApiCallOrder,
  expectListContains,
  expectListItem,
  expectBackStack,
  expectCanGoBack,
  expectSemanticsLabel,
}

extension TestStepArgKindSchema on TestStepArgKind {
  static const _string = {'type': 'string'};
  static const _integer = {'type': 'integer'};
  static const _boolean = {'type': 'boolean'};
  static const _any = true;

  static Map<String, dynamic> _object({
    Map<String, dynamic>? properties,
    List<String>? required,
    bool additionalProperties = false,
  }) =>
      {
        'type': 'object',
        if (properties != null) 'properties': properties,
        if (required != null && required.isNotEmpty) 'required': required,
        'additionalProperties': additionalProperties,
      };

  static Map<String, dynamic> _ref(String name) => {'\$ref': '#/\$defs/$name'};

  /// JSON Schema for this step's YAML argument object.
  Map<String, dynamic> get jsonSchema {
    switch (this) {
      case TestStepArgKind.empty:
        return _object();
      case TestStepArgKind.openScreen:
        return _object(properties: {'screen': _string, 'name': _string});
      case TestStepArgKind.trigger:
        return _object(
          properties: {
            'action': {
              'type': 'string',
              'enum': ['onLoad', 'onTap', 'onLongPress'],
            },
            'id': _string,
          },
          required: ['action'],
        );
      case TestStepArgKind.idRequired:
        return _object(properties: {'id': _string}, required: ['id']);
      case TestStepArgKind.idOptional:
        return _object(properties: {'id': _string});
      case TestStepArgKind.enterText:
        return _object(
          properties: {'id': _string, 'value': _any, 'submit': _boolean},
          required: ['id'],
        );
      case TestStepArgKind.select:
        return _object(
          properties: {'id': _string, 'value': _string},
          required: ['id', 'value'],
        );
      case TestStepArgKind.selectIndex:
        return _object(
          properties: {'id': _string, 'index': _integer},
          required: ['id'],
        );
      case TestStepArgKind.setSlider:
        return _object(
          properties: {
            'id': _string,
            'value': {'type': 'number'}
          },
          required: ['id'],
        );
      case TestStepArgKind.chooseValue:
        return _object(
          properties: {'id': _string, 'value': _string},
          required: ['id', 'value'],
        );
      case TestStepArgKind.scroll:
        return _object(properties: {'delta': _integer});
      case TestStepArgKind.swipe:
        return _object(
          properties: {
            'direction': {
              'type': 'string',
              'enum': ['left', 'right', 'up', 'down'],
            },
            'id': _string,
          },
        );
      case TestStepArgKind.drag:
        return _object(
          properties: {
            'id': _string,
            'dx': {'type': 'number'},
            'dy': {'type': 'number'},
          },
          required: ['id'],
        );
      case TestStepArgKind.pump:
        return _object(properties: {'durationMs': _integer});
      case TestStepArgKind.timeoutOptional:
        return _object(properties: {'timeoutMs': _integer});
      case TestStepArgKind.httpRequest:
        return _object(
          properties: {
            'url': _string,
            'method': {
              'type': 'string',
              'enum': [
                'GET',
                'POST',
                'PUT',
                'PATCH',
                'DELETE',
                'HEAD',
                'OPTIONS',
              ],
            },
            'headers': {
              'type': 'object',
              'additionalProperties': true,
            },
            'body': _any,
            'timeoutMs': _integer,
            'expectStatus': _integer,
            'expectBodyContains': _string,
          },
          required: ['url'],
        );
      case TestStepArgKind.runCommand:
        return _object(
          properties: {
            'command': _string,
            'arguments': {
              'type': 'array',
              'items': _any,
            },
            'workingDirectory': _string,
            'environment': {
              'type': 'object',
              'additionalProperties': true,
            },
            'timeoutMs': _integer,
            'expectExitCode': _integer,
          },
          required: ['command'],
        );
      case TestStepArgKind.waitFor:
        return _object(
          properties: {'id': _string, 'text': _string, 'timeoutMs': _integer},
        );
      case TestStepArgKind.waitForGone:
        return _object(
          properties: {'id': _string, 'timeoutMs': _integer},
          required: ['id'],
        );
      case TestStepArgKind.waitForNavigation:
        return _object(
          properties: {'screen': _string, 'timeoutMs': _integer},
          required: ['screen'],
        );
      case TestStepArgKind.textRequired:
        return _object(properties: {'text': _string}, required: ['text']);
      case TestStepArgKind.expectEquals:
        return _object(
          properties: {'id': _string, 'equals': _any},
          required: ['id', 'equals'],
        );
      case TestStepArgKind.expectChecked:
        return _object(
          properties: {'id': _string, 'equals': _boolean},
          required: ['id'],
        );
      case TestStepArgKind.expectProperty:
        return _object(
          properties: {'id': _string, 'property': _string, 'equals': _any},
          required: ['id', 'equals'],
        );
      case TestStepArgKind.expectCount:
        return _object(
          properties: {'id': _string, 'equals': _integer},
          required: ['id', 'equals'],
        );
      case TestStepArgKind.expectListCount:
        return _object(
          properties: {'id': _string, 'itemId': _string, 'equals': _integer},
          required: ['equals'],
        );
      case TestStepArgKind.screenRequired:
        return _object(
          properties: {'screen': _string, 'name': _string},
          required: ['screen'],
        );
      case TestStepArgKind.expectVisited:
        return _object(
          properties: {'screen': _string},
          required: ['screen'],
        );
      case TestStepArgKind.apiName:
        return _object(
          properties: {'name': _string, 'times': _integer},
          required: ['name'],
        );
      case TestStepArgKind.storageKey:
        return _object(
          properties: {'key': _string, 'equals': _any, 'value': _any},
          required: ['key'],
        );
      case TestStepArgKind.group:
        return _object(
          properties: {
            'name': _string,
            'steps': {'type': 'array', 'items': _ref('step'), 'minItems': 1},
          },
          required: ['steps'],
        );
      case TestStepArgKind.repeat:
        return _object(
          properties: {
            'times': _integer,
            'steps': {'type': 'array', 'items': _ref('step'), 'minItems': 1},
          },
          required: ['times', 'steps'],
        );
      case TestStepArgKind.optional:
        return _object(
          properties: {
            'step': _ref('step'),
            'steps': {'type': 'array', 'items': _ref('step'), 'minItems': 1},
          },
        );
      case TestStepArgKind.ifVisible:
        return _object(
          properties: {
            'id': _string,
            'step': _ref('step'),
            'steps': {'type': 'array', 'items': _ref('step'), 'minItems': 1},
          },
          required: ['id'],
        );
      case TestStepArgKind.setAuth:
        return _object(
          properties: {
            'user': {'type': 'object', 'additionalProperties': true},
          },
          required: ['user'],
        );
      case TestStepArgKind.setPermission:
        return _object(
          properties: {'name': _string, 'value': _string},
          required: ['name'],
        );
      case TestStepArgKind.setDevice:
        return _object(
          properties: {
            'width': {'type': 'number'},
            'height': {'type': 'number'},
          },
        );
      case TestStepArgKind.setLocale:
        return _object(properties: {'locale': _string});
      case TestStepArgKind.setTheme:
        return _object(properties: {'mode': _string, 'theme': _string});
      case TestStepArgKind.runScript:
        return _object(
          properties: {'script': _string, 'path': _string, 'equals': _any},
        );
      case TestStepArgKind.expectConsoleLog:
        return _object(
          properties: {'contains': _string},
          required: ['contains'],
        );
      case TestStepArgKind.expectErrorContains:
        return _object(properties: {'contains': _string});
      case TestStepArgKind.expectApiCallOrder:
        return _object(
          properties: {
            'names': {
              'type': 'array',
              'items': _string,
              'minItems': 1,
            },
          },
          required: ['names'],
        );
      case TestStepArgKind.expectListContains:
        return _object(
          properties: {'id': _string, 'text': _string},
          required: ['id', 'text'],
        );
      case TestStepArgKind.expectListItem:
        return _object(
          properties: {'itemId': _string},
          required: ['itemId'],
        );
      case TestStepArgKind.expectBackStack:
        return _object(
          properties: {
            'screens': {
              'type': 'array',
              'items': _string,
              'minItems': 1,
            },
          },
          required: ['screens'],
        );
      case TestStepArgKind.expectCanGoBack:
        return _object(properties: {'equals': _boolean});
      case TestStepArgKind.expectSemanticsLabel:
        return _object(
          properties: {'id': _string, 'label': _string},
          required: ['id', 'label'],
        );
    }
  }
}
