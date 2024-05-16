import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart';

extension Value on TextFormField {
  String get value => controller!.value.text;

  set value(String newValue) {
    controller!.text = newValue;
  }
  void setValue(String v) {
    controller!.text = v;
  }
  Map<String, dynamic> toJson() => {'value': value};
}
extension Json on Response {
  Map<String, dynamic> toJson() {
    return jsonDecode(body);
  }
}

extension WidgetProps on Widget {

  void setProperty(String name,var value) {
    if ( name == 'value' ) {
      this.value = value;
    }
  }
  getProperty(String name) {
    if ( name == 'value' ) {
      return value;
    }
    throw Exception(name+' is not recognized as a property of object '+this.toString());
  }
  set value(String newValue) {
    if ( this is TextFormField ) {
      (this as TextFormField).value = newValue;
    } else {
      //fix this as we add widgets
      throw Exception("value is not supported on "+this.toString());
    }
  }
  String get value {
    String rtn = '';
    if ( this is TextFormField ) {
      rtn = (this as TextFormField).value;
    } else {
      //fix this as we add widgets
      throw Exception("value is not supported on "+this.toString());
    }
    return rtn;
  }
  Map<String, dynamic> toJson() {
    Map<String, dynamic> rtn = HashMap();
    if ( this is TextFormField ) {
      rtn = (this as TextFormField).toJson();
    } else {
      //fix this as we add widgets
      throw Exception("toJson is not supported on "+this.toString());
    }
    return rtn;
  }
}