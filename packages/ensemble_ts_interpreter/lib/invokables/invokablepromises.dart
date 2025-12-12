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
      try {
        final r = onFinally([]);
        if (r is JSPromise) {
          return r.then((_) => v);
        }
        return v;
      } catch (e) {
        throw e;
      }
    }, (e) {
      try {
        final r = onFinally([]);
        if (r is JSPromise) {
          return r.then((_) => throw e);
        }
        throw e;
      } catch (err) {
        throw err;
      }
    });
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
        result.then((v) => resolve(v), (e) => reject(e));
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
        result.then((v) => resolve(v), (e) => reject(e));
      } else {
        resolve(result);
      }
    } catch (e) {
      reject(e);
    }
  }
}
