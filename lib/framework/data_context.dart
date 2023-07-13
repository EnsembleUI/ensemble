import 'dart:developer';
import 'dart:io' as io;
import 'package:ensemble/framework/config.dart';
import 'package:ensemble/framework/device.dart';
import 'package:ensemble/framework/error_handling.dart';
import 'package:ensemble/framework/widget/view_util.dart';
import 'package:ensemble/util/extensions.dart';
import 'package:ensemble/util/notification_utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokablecontroller.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:get_storage/get_storage.dart';

import 'package:ensemble/framework/action.dart';
import 'package:ensemble/screen_controller.dart';
import 'package:ensemble/util/http_utils.dart';
import 'package:ensemble/util/utils.dart';
import 'package:ensemble_ts_interpreter/invokables/invokableprimitives.dart';
import 'package:ensemble_ts_interpreter/parser/newjs_interpreter.dart';
import 'package:flutter/cupertino.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';
import 'package:ensemble_ts_interpreter/errors.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:mime/mime.dart';
import 'package:source_span/source_span.dart';
import 'package:walletconnect_dart/walletconnect_dart.dart';
import 'package:yaml/yaml.dart';

/// manages Data and Invokables within the current data scope.
/// This class can evaluate expressions based on the data scope
class DataContext {
  final Map<String, dynamic> _contextMap = {};
  final BuildContext buildContext;

  DataContext({required this.buildContext, Map<String, dynamic>? initialMap}) {
    if (initialMap != null) {
      _contextMap.addAll(initialMap);
    }
    _contextMap['app'] = AppConfig();
    _contextMap['env'] = EnvConfig();
    _contextMap['ensemble'] = NativeInvokable(buildContext);
    _contextMap['user'] = UserInfo();
    // device is a common name. If user already uses that, don't override it
    if (_contextMap['device'] == null) {
      _contextMap['device'] = Device();
    }
  }

  DataContext clone({BuildContext? newBuildContext}) {
    return DataContext(
        buildContext: newBuildContext ?? buildContext, initialMap: _contextMap);
  }

  /// copy over the additionalContext,
  /// skipping over duplicate keys if replaced is false
  void copy(DataContext additionalContext, {bool replaced = false}) {
    // copy all fields if replaced is true
    if (replaced) {
      _contextMap.addAll(additionalContext._contextMap);
    }
    // iterate and skip duplicate
    else {
      additionalContext._contextMap.forEach((key, value) {
        if (_contextMap[key] == null) {
          _contextMap[key] = value;
        }
      });
    }
  }

  // raw data (data map, api result), traversable with dot and bracket notations
  void addDataContext(Map<String, dynamic> data) {
    _contextMap.addAll(data);
  }

  void addDataContextById(String id, dynamic value) {
    if (value != null) {
      _contextMap[id] = value;
    }
  }

  /// invokable widget, traversable with getters, setters & methods
  /// Note that this will change a reference to the object, meaning the
  /// parent scope will not get the changes to this.
  /// Make sure the scope is finalized before creating child scope, or
  /// should we just travel up the parents and update their references??
  void addInvokableContext(String id, Invokable widget) {
    _contextMap[id] = widget;
  }

  bool hasContext(String id) {
    return _contextMap[id] != null;
  }

  /// return the data context value given the ID
  dynamic getContextById(String id) {
    return _contextMap[id];
  }

  /// evaluate single inline binding expression (getters only) e.g Hello ${myVar.name}.
  /// Note that this expects the variable (if any) to be inside ${...}
  dynamic eval(dynamic expression) {
    if (expression is YamlMap) {
      return _evalMap(expression);
    }
    if (expression is List) {
      return _evalList(expression);
    }
    if (expression is! String) {
      return expression;
    }

    // execute as code if expression is AST
    if (expression.startsWith("//@code")) {
      return evalCode(expression, ViewUtil.optDefinition(null));
    }

    // if just have single standalone expression, return the actual type (e.g integer)
    // this is the distinction here so we can continue to walk down the path
    // if the return type is JSON
    RegExpMatch? simpleExpression = Utils.onlyExpression.firstMatch(expression);
    if (simpleExpression != null) {
      return asObject(evalVariable(simpleExpression.group(1)!));
    }
    // if we have multiple expressions, or mixing with text, return as String
    // greedy match anything inside a $() with letters, digits, period, square brackets.
    // Note that since we combine multiple expressions together, the end result
    // has to be a string.
    return expression.replaceAllMapped(Utils.containExpression,
        (match) => asString(evalVariable("${match[1]}")));

    /*return replaceAllMappedAsync(
        expression,
        RegExp(r'\$\(([a-z_-\d."\(\)\[\]]+)\)', caseSensitive: false),
        (match) async => (await evalVariable("${match[1]}")).toString()
    );*/
  }

  List _evalList(List list) {
    List value = [];
    for (var i in list) {
      value.add(eval(i));
    }
    return value;
  }

  Map<String, dynamic> _evalMap(YamlMap yamlMap) {
    Map<String, dynamic> map = {};
    yamlMap.forEach((k, v) {
      dynamic value;
      if (v is YamlMap) {
        value = _evalMap(v);
      } else if (v is YamlList) {
        value = _evalList(v);
      } else {
        value = eval(v);
      }
      map[k] = value;
    });
    return map;
  }

  /// format the expression result for user consumption
  /// Here we make sure the output is purely string and
  /// is friendly (not null or InvokableNull)
  String asString(dynamic input) {
    if (input is InvokableNull) {
      return '';
    }
    return input?.toString() ?? '';
  }

  /// return the input as its original object, but also inject
  /// some user-friendliness output (not null, not InvokableNull)
  dynamic asObject(dynamic input) {
    if (input is InvokableNull) {
      return '';
    }
    return input ?? '';
  }

  Future<String> replaceAllMappedAsync(String string, Pattern exp,
      Future<String> Function(Match match) replace) async {
    StringBuffer replaced = StringBuffer();
    int currentIndex = 0;
    for (Match match in exp.allMatches(string)) {
      String prefix = match.input.substring(currentIndex, match.start);
      currentIndex = match.end;
      replaced
        ..write(prefix)
        ..write(await replace(match));
    }
    replaced.write(string.substring(currentIndex));
    return replaced.toString();
  }

  /// evaluate Typescript code block
  dynamic evalCode(String codeBlock, SourceSpan definition) {
    // code can have //@code <expression>
    // We don't use that here but we need to strip
    // that out before passing it to the JSInterpreter

    SourceLocation startLoc = definition.start;
    String? codeWithoutComments =
        Utils.codeAfterComment.firstMatch(codeBlock)?.group(1);
    if (codeWithoutComments != null) {
      codeBlock = codeWithoutComments;
      startLoc = SourceLocationBase(0,
          sourceUrl: startLoc.sourceUrl, line: startLoc.line + 2);
    }
    //https://github.com/EnsembleUI/ensemble/issues/249
    if (codeBlock.isEmpty) {
      //just don't do anything and return.
      return null;
    }
    try {
      _contextMap['getStringValue'] = Utils.optionalString;
      return JSInterpreter.fromCode(codeBlock, _contextMap).evaluate();
    } on JSException catch (e) {
      /// not all JS errors are actual errors. API binding resolving to null
      /// may be considered a normal condition as binding may not resolved
      /// until later e.g myAPI.value.prettyDateTime()
      FlutterError.reportError(FlutterErrorDetails(
        exception: CodeError(e, startLoc),
        library: 'Javascript',
        context: ErrorSummary(
            'Javascript error when running code block - $codeBlock'),
      ));
      return null;
    }
  }

  dynamic evalToken(List<String> tokens, int index, dynamic data) {
    // can't go further, return data
    if (index == tokens.length) {
      return data;
    }

    if (data is Map) {
      return evalToken(tokens, index + 1, data[tokens[index]]);
    } else {
      String token = tokens[index];
      if (InvokableController.getGettableProperties(data).contains(token)) {
        return evalToken(tokens, index + 1, data.getProperty(token));
      } else {
        // only support methods with 0 or 1 argument for now
        RegExpMatch? match =
            RegExp(r'''([a-zA-Z_-\d]+)\s*\(["']?([a-zA-Z_-\d:.]*)["']?\)''')
                .firstMatch(token);
        if (match != null) {
          // first group is the method name, second is the argument
          Function? method =
              InvokableController.getMethods(data)[match.group(1)];
          if (method != null) {
            // our match will always have 2 groups. Second group is the argument
            // which could be empty since we use ()*
            List<String> args = [];
            if (match.group(2)!.isNotEmpty) {
              args.add(match.group(2)!);
            }
            dynamic nextData = Function.apply(method, args);
            return evalToken(tokens, index + 1, nextData);
          }
        }
        // return null since we can't find any matching methods/getters on this Invokable
        return null;
      }
    }
  }

  /// evaluate a single variable expression e.g myVariable.value.
  /// Note: use eval() if your variable are surrounded by ${...}
  dynamic evalVariable(String variable) {
    try {
      return JSInterpreter.fromCode(variable, _contextMap).evaluate();
    } catch (error) {
      // TODO: we want to show errors in most case
      //  Exception: 1) API has not been loaded, 2) Custom widget input (also awaiting API)
      // perhaps don't process if we know API has not been called
      log('JS Parsing Error: $error');
    }
    return null;
  }

  /// token format: result
  static dynamic _parseToken(
      List<String> tokens, int index, Map<String, dynamic> map) {
    if (index == tokens.length - 1) {
      return map[tokens[index]];
    }
    if (map[tokens[index]] == null) {
      return null;
    }
    return _parseToken(tokens, index + 1, map[tokens[index]]);
  }
}

/// built-in helpers/utils accessible to all DataContext
class NativeInvokable with Invokable {
  final BuildContext _buildContext;
  NativeInvokable(this._buildContext);

  @override
  Map<String, Function> getters() {
    return {
      'storage': () => EnsembleStorage(_buildContext),
      'formatter': () => Formatter(_buildContext),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      ActionType.navigateScreen.name: navigateToScreen,
      ActionType.navigateModalScreen.name: navigateToModalScreen,
      ActionType.showDialog.name: showDialog,
      ActionType.invokeAPI.name: invokeAPI,
      ActionType.stopTimer.name: stopTimer,
      ActionType.openCamera.name: showCamera,
      ActionType.navigateBack.name: navigateBack,
      ActionType.uploadFiles.name: uploadFiles,
      'debug': (value) => debugPrint('Debug: $value'),
      'copyToClipboard': (value) =>
          Clipboard.setData(ClipboardData(text: value)),
      'initNotification': () => notificationUtils.initNotifications(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  void uploadFiles(dynamic inputs) {
    Map<String, dynamic>? inputMap = Utils.getMap(inputs);
    if (inputMap == null) throw LanguageError('UploadFiles need inputs');
    ScreenController().executeAction(
      _buildContext,
      FileUploadAction.fromYaml(payload: YamlMap.wrap(inputMap)),
    );
  }

  void navigateToScreen(String screenName, [dynamic inputs]) {
    Map<String, dynamic>? inputMap = Utils.getMap(inputs);
    ScreenController().navigateToScreen(_buildContext,
        screenName: screenName, pageArgs: inputMap, asModal: false);
  }

  void navigateToModalScreen(String screenName, [dynamic inputs]) {
    Map<String, dynamic>? inputMap = Utils.getMap(inputs);
    ScreenController().navigateToScreen(_buildContext,
        screenName: screenName, pageArgs: inputMap, asModal: true);
    // how do we handle onModalDismiss in Typescript?
  }

  void showDialog(dynamic widget) {
    ScreenController()
        .executeAction(_buildContext, ShowDialogAction(widget: widget));
  }

  void invokeAPI(String apiName, [dynamic inputs]) {
    Map<String, dynamic>? inputMap = Utils.getMap(inputs);
    ScreenController().executeAction(
        _buildContext, InvokeAPIAction(apiName: apiName, inputs: inputMap));
  }

  void stopTimer(String timerId) {
    ScreenController().executeAction(_buildContext, StopTimerAction(timerId));
  }

  void showCamera() {
    ScreenController().executeAction(_buildContext, ShowCameraAction());
  }

  void navigateBack() {
    ScreenController().executeAction(_buildContext, NavigateBack());
  }
}

/// Singleton handling user storage
class EnsembleStorage with Invokable {
  static final EnsembleStorage _instance = EnsembleStorage._internal();
  EnsembleStorage._internal();
  factory EnsembleStorage(BuildContext buildContext) {
    context = buildContext;
    return _instance;
  }
  static late BuildContext context;
  final storage = GetStorage();

  @override
  void setProperty(prop, val) {
    if (prop is String) {
      if (val == null) {
        storage.remove(prop);
      } else {
        storage.write(prop, val);
      }
      // dispatch changes
      ScreenController().dispatchStorageChanges(context, prop, val);
    }
  }

  @override
  getProperty(prop) {
    return prop is String ? storage.read(prop) : null;
  }

  @override
  Map<String, Function> getters() {
    throw UnimplementedError();
  }

  @override
  Map<String, Function> methods() {
    return {
      'get': (String key) => storage.read(key),
      'set': (String key, dynamic value) =>
          value == null ? storage.remove(key) : storage.write(key, value),
      'delete': (key) => storage.remove(key)
    };
  }

  @override
  Map<String, Function> setters() {
    throw UnimplementedError();
  }
}

class Formatter with Invokable {
  final BuildContext _buildContext;
  Formatter(this._buildContext);

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    Locale? locale = Localizations.localeOf(Utils.globalAppKey.currentContext!);
    return {
      'now': () => UserDateTime(),
      'prettyDate': (input) => InvokablePrimitive.prettyDate(input),
      'prettyTime': (input) => InvokablePrimitive.prettyTime(input),
      'prettyDateTime': (input) => InvokablePrimitive.prettyDateTime(input),
      'prettyCurrency': (input) => InvokablePrimitive.prettyCurrency(input),
      'prettyDuration': (input) =>
          InvokablePrimitive.prettyDuration(input, locale: locale),
      'pluralize': pluralize
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  String pluralize(String singularText, int? count, [pluralText]) {
    count ??= 1;
    if (count <= 1) {
      return singularText;
    }
    return pluralText ?? '${singularText}s';
  }
}

class UserInfo with Invokable {
  @override
  Map<String, Function> getters() {
    return {
      'date': () => DateInfo(),
      'datetime': () => DateTimeInfo(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

/// represents a date and its operations
class DateInfo with Invokable {
  DateInfo({this.value});

  DateTime? value;
  DateTime get dateTime => value ?? DateTime.now();
  Locale locale = Localizations.localeOf(Utils.globalAppKey.currentContext!);

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'plusDays': (int days) =>
          DateInfo(value: dateTime.add(Duration(days: days))),
      'plusYears': (int years) =>
          DateInfo(value: dateTime.add(Duration(days: years * 365))),
      'minusDays': (int days) =>
          DateInfo(value: dateTime.add(Duration(days: -days))),
      'minusYears': (int years) =>
          DateInfo(value: dateTime.add(Duration(days: -years * 365))),
      'getMonth': () => dateTime.month,
      'getDay': () => dateTime.day,
      'getDayOfWeek': () => dateTime.weekday,
      'getYear': () => dateTime.year,
      'pretty': () => DateFormat.yMMMd(locale.toString()).format(dateTime),
      'format': (String format) =>
          DateFormat(format, locale.toString()).format(dateTime),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  @override
  String toString() {
    return dateTime.toIso8601DateString();
  }
}

/// represents a datetime and its operations
class DateTimeInfo with Invokable {
  DateTimeInfo({this.value});

  DateTime? value;
  DateTime get dateTime => value ?? DateTime.now();
  Locale locale = Localizations.localeOf(Utils.globalAppKey.currentContext!);

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'plusDays': (int days) =>
          DateInfo(value: dateTime.add(Duration(days: days))),
      'plusYears': (int years) =>
          DateInfo(value: dateTime.add(Duration(days: years * 365))),
      'plusHours': (int hours) =>
          DateInfo(value: dateTime.add(Duration(hours: hours))),
      'plusMinutes': (int minutes) =>
          DateInfo(value: dateTime.add(Duration(minutes: minutes))),
      'plusSeconds': (int seconds) =>
          DateInfo(value: dateTime.add(Duration(seconds: seconds))),
      'minusDays': (int days) =>
          DateInfo(value: dateTime.add(Duration(days: -days))),
      'minusYears': (int years) =>
          DateInfo(value: dateTime.add(Duration(days: -years * 365))),
      'minusHours': (int hours) =>
          DateInfo(value: dateTime.add(Duration(hours: -hours))),
      'minusMinutes': (int minutes) =>
          DateInfo(value: dateTime.add(Duration(minutes: -minutes))),
      'minusSeconds': (int seconds) =>
          DateInfo(value: dateTime.add(Duration(seconds: -seconds))),
      'getMonth': () => dateTime.month,
      'getDay': () => dateTime.day,
      'getDayOfWeek': () => dateTime.weekday,
      'getYear': () => dateTime.year,
      'getHour': () => dateTime.hour,
      'getMinute': () => dateTime.minute,
      'getSecond': () => dateTime.second,
      'pretty': () =>
          DateFormat.yMMMd(locale.toString()).format(dateTime) +
          ' ' +
          DateFormat.jm(locale.toString()).format(dateTime),
      'format': (String format) =>
          DateFormat(format, locale.toString()).format(dateTime),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  @override
  String toString() {
    return dateTime.toIso8601String();
  }
}

/// legacy
class UserDateTime with Invokable {
  DateTime? _dateTime;
  DateTime get dateTime => _dateTime ??= DateTime.now();

  @override
  Map<String, Function> getters() {
    return {};
  }

  @override
  Map<String, Function> methods() {
    return {
      'getDate': () => dateTime.toIso8601DateString(),
      'getDateTime': () => dateTime.toIso8601String(),
      'prettyDate': () => DateFormat.yMMMd().format(dateTime),
      'prettyDateTime': () =>
          DateFormat.yMMMd().format(dateTime) +
          ' ' +
          DateFormat.jm().format(dateTime),
      'getMonth': () => dateTime.month,
      'getDay': () => dateTime.day,
      'getDayOfWeek': () => dateTime.weekday,
      'getYear': () => dateTime.year,
      'getHour': () => dateTime.hour,
      'getMinute': () => dateTime.minute,
      'getSecond': () => dateTime.second,
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class APIResponse with Invokable {
  Response? _response;
  double? _progress;
  APIResponse({Response? response}) {
    if (response != null) {
      setAPIResponse(response);
    }
  }

  setAPIResponse(Response response) {
    _response = response;
  }

  setProgress(double progress) {
    _progress = progress;
  }

  Response? getAPIResponse() {
    return _response;
  }

  @override
  Map<String, Function> getters() {
    return {
      'body': () => _response?.body,
      'headers': () => _response?.headers,
      'progress': () => _progress,
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class ModifiableAPIResponse extends APIResponse {
  ModifiableAPIResponse({required Response response})
      : super(response: response);

  @override
  Map<String, Function> setters() {
    return {
      'body': (newBody) =>
          _response!.body = HttpUtils.parseResponsePayload(newBody),
      'headers': (newHeaders) =>
          _response!.headers = HttpUtils.parseResponsePayload(newHeaders)
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'addHeader': (key, value) {
        Map<String, dynamic> headers = (_response!.headers ?? {});
        headers[key] = value;
        _response!.headers = headers;
      }
    };
  }
}

class FileData with Invokable {
  FileData({List<File>? files}) : _files = files;

  final List<File>? _files;

  @override
  Map<String, Function> getters() {
    return {
      'files': () => _files?.map((file) => file.toJson()).toList(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {};
  }

  @override
  Map<String, Function> setters() {
    return {};
  }
}

class File {
  File(this.name, this.ext, this.size, this.path, this.bytes);

  File.fromPlatformFile(PlatformFile file)
      : name = file.name,
        ext = file.extension,
        size = file.size,
        path = kIsWeb ? null : file.path,
        bytes = file.bytes;

  File.fromJson(Map<String, dynamic> file)
      : name = file['name'],
        ext = file['extension'],
        size = file['size'],
        path = file['path'],
        bytes = file['bytes'];

  final String name;

  /// The file size in bytes. Defaults to `0` if the file size could not be
  /// determined.
  final int size;
  final String? ext;
  final String? path;
  final Uint8List? bytes;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'extension': ext,
      'size': size,
      'path': path,
      'bytes': bytes,
      'mediaType': getMediaType().name,
    };
  }

  io.File? toFile() {
    if (path == null) return null;
    return io.File(path!);
  }

  MediaType getMediaType() {
    String? mimeType = lookupMimeType(path ?? '', headerBytes: bytes);
    if (mimeType == null) {
      return MediaType.unknown;
    }
    if (mimeType.startsWith('image/')) {
      return MediaType.image;
    } else if (mimeType.startsWith('video/')) {
      return MediaType.video;
    } else if (mimeType.startsWith('audio/')) {
      return MediaType.audio;
    } else {
      return MediaType.unknown;
    }
  }
}

enum MediaType {
  image,
  video,
  audio,
  unknown,
}

class WalletData with Invokable {
  WalletData(this.walletConnect);

  final WalletConnect walletConnect;

  @override
  Map<String, Function> getters() {
    return {
      'addresses': () => walletConnect.session.accounts,
      'connectionUri': () => walletConnect.session.toUri().toString(),
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'closeConnection': () => closeConnection(),
    };
  }

  @override
  Map<String, Function> setters() {
    return {};
  }

  void closeConnection() {
    walletConnect.killSession();
    walletConnect.close();
  }
}
