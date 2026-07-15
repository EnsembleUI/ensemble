import 'dart:async';

import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

enum _PromiseState { pending, fulfilled, rejected }

class JSPromiseConstructor extends Object with Invokable {
  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'init': (Function executor) => JSPromise(executor),
      'resolve': (dynamic value) => JSPromise.resolve(value),
      'reject': (dynamic reason) => JSPromise.reject(reason),
      'fromFuture': (Future<dynamic> fut) => JSPromise.fromFuture(fut),
      'all': (List values) => JSPromise.all(values),
      'allSettled': (List values) => JSPromise.allSettled(values),
      'race': (List values) => JSPromise.race(values),
      'any': (List values) => JSPromise.any(values),
    };
  }

  @override
  Map<String, Function> setters() => {};
}

class JSPromise extends Object with Invokable {
  _PromiseState _state = _PromiseState.pending;
  dynamic _value;
  final List<_PromiseHandler> _handlers = [];

  // Static utilities
  static JSPromise resolve(dynamic value) {
    return JSPromise((List funcs) {
      final resolve = funcs[0];
      resolve(value);
    });
  }

  static JSPromise reject(dynamic reason) {
    return JSPromise((List funcs) {
      final reject = funcs[1];
      reject(reason);
    });
  }

  static JSPromise fromFuture(Future<dynamic> future) {
    return JSPromise((List funcs) {
      final resolve = funcs[0];
      final reject = funcs[1];
      future.then((v) => resolve(v)).catchError((e) => reject(e));
    });
  }

  static JSPromise all(List values) {
    return JSPromise.fromFuture(
        Future.wait(values.map((value) => _awaitValue(value)).toList()));
  }

  static JSPromise allSettled(List values) {
    return JSPromise.fromFuture(Future.wait(values.map((value) async {
      try {
        return {'status': 'fulfilled', 'value': await _awaitValue(value)};
      } catch (error) {
        return {'status': 'rejected', 'reason': error};
      }
    }).toList()));
  }

  static JSPromise race(List values) {
    return JSPromise.fromFuture(
        Future.any(values.map((value) => _awaitValue(value)).toList()));
  }

  static JSPromise any(List values) {
    return JSPromise((List funcs) {
      final resolve = funcs[0];
      final reject = funcs[1];
      if (values.isEmpty) {
        reject(<dynamic>[]);
        return;
      }
      final errors = <dynamic>[];
      var remaining = values.length;
      for (final value in values) {
        _awaitValue(value).then((resolved) {
          resolve(resolved);
        }).catchError((error) {
          errors.add(error);
          remaining--;
          if (remaining == 0) reject(errors);
        });
      }
    });
  }

  static Future<dynamic> _awaitValue(dynamic value) {
    if (value is JSPromise) return value.toFuture();
    if (value is Future) return value;
    return Future<dynamic>.value(value);
  }

  JSPromise(Function executor) {
    void resolve(value) => _resolve(value);
    void reject(reason) => _reject(reason);
    try {
      executor([resolve, reject]);
    } catch (e) {
      _reject(e);
    }
  }

  void _resolve(dynamic value) {
    if (_state != _PromiseState.pending) return;
    if (value is JSPromise) {
      value.then((v) => _resolve(v), (e) => _reject(e));
      return;
    }
    _settle(_PromiseState.fulfilled, value);
  }

  void _reject(dynamic reason) {
    if (_state != _PromiseState.pending) return;
    _settle(_PromiseState.rejected, reason);
  }

  void _settle(_PromiseState state, dynamic val) {
    _state = state;
    _value = val;
    scheduleMicrotask(_runHandlers);
  }

  void _runHandlers() {
    while (_handlers.isNotEmpty) {
      final handler = _handlers.removeAt(0);
      if (_state == _PromiseState.fulfilled) {
        handler.handleFulfilled(_value);
      } else if (_state == _PromiseState.rejected) {
        handler.handleRejected(_value);
      }
    }
  }

  JSPromise then([Function? onFulfilled, Function? onRejected]) {
    return JSPromise((List funcs) {
      final resolve = funcs[0];
      final reject = funcs[1];
      final h = _PromiseHandler(onFulfilled, onRejected, resolve, reject);
      _handlers.add(h);
      if (_state != _PromiseState.pending) {
        scheduleMicrotask(_runHandlers);
      }
    });
  }

  JSPromise catch_(Function onRejected) {
    return then(null, onRejected);
  }

  JSPromise finally_(Function onFinally) {
    return then((v) {
      final original = v is List && v.isNotEmpty ? v.first : v;
      try {
        final r = onFinally([]);
        if (r is JSPromise) {
          return r.then((_) => original);
        }
        return original;
      } catch (e) {
        throw e;
      }
    }, (e) {
      final reason = e is List && e.isNotEmpty ? e.first : e;
      try {
        final r = onFinally([]);
        if (r is JSPromise) {
          return r.then((_) => throw reason);
        }
        throw reason;
      } catch (err) {
        throw err;
      }
    });
  }

  Future<dynamic> toFuture() {
    final completer = Completer<dynamic>();
    then((args) {
      completer.complete(args is List && args.isNotEmpty ? args.first : args);
    }, (args) {
      final reason = args is List && args.isNotEmpty ? args.first : args;
      completer.completeError(reason);
    });
    return completer.future;
  }

  @override
  Map<String, Function> getters() => {};

  @override
  Map<String, Function> methods() {
    return {
      'then': then,
      'catch': catch_,
      'finally': finally_,
    };
  }

  @override
  Map<String, Function> setters() => {};
}

class _PromiseHandler {
  final Function? onFulfilled;
  final Function? onRejected;
  final Function resolve;
  final Function reject;

  _PromiseHandler(this.onFulfilled, this.onRejected, this.resolve, this.reject);

  void handleFulfilled(dynamic value) {
    if (onFulfilled == null) {
      resolve(value);
      return;
    }
    try {
      final result = onFulfilled!([value]);
      if (result is JSPromise) {
        result.then(
            (v) => resolve(_singleArg(v)), (e) => reject(_singleArg(e)));
      } else {
        resolve(result);
      }
    } catch (e) {
      reject(e);
    }
  }

  void handleRejected(dynamic reason) {
    if (onRejected == null) {
      reject(reason);
      return;
    }
    try {
      final result = onRejected!([reason]);
      if (result is JSPromise) {
        result.then(
            (v) => resolve(_singleArg(v)), (e) => reject(_singleArg(e)));
      } else {
        resolve(result);
      }
    } catch (e) {
      reject(e);
    }
  }

  dynamic _singleArg(dynamic value) =>
      value is List && value.isNotEmpty ? value.first : value;
}
