import 'dart:math';

import 'package:flutter/material.dart';
import 'package:ensemble_ts_interpreter/invokables/invokable.dart';

class InvokableTextFormField extends TextFormField with Invokable {
   InvokableTextFormField({
     Key? key,
     TextEditingController? controller,
     InputDecoration? decoration
   }) : super(key: key,controller:controller,decoration:decoration);

  void toUppercase() {
    setters()['value']!(getters()['value']!().toString().toUpperCase());
  }
  int random(int seed,int max) {
    return Random(seed).nextInt(max);
  }

  @override
  Map<String, Function> getters() {
    return {
      'value': () => controller!.value.text
    };
  }

  @override
  Map<String, Function> methods() {
    return {
      'random': (int seed,int max) { return random(seed,max);},
      'toUpperCase': () => toUppercase(),
      'indexOf': (String str) { return controller!.value.text.indexOf(str);}
    };
  }

  @override
  Map<String, Function> setters() {
    return {
      'value': (newValue) => controller!.text = newValue,
    };
  }

  @override
  dynamic getProperty(dynamic prop) {
    Function? f = getters()[prop];
    if ( f != null ) {
      return f();
    }
    throw Exception('getter by name='+prop+' is not defined on this object='+toString());
  }

  @override
  void setProperty(dynamic prop, dynamic val) {
    Function? f = setters()[prop];
    if ( f != null ) {
      f(val);
    }
  }

}


