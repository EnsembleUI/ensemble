// Copyright 2009 the Sputnik authors.  All rights reserved.
// This code is governed by the BSD license found in the LICENSE file.

/*---
info: SPACE (U+0020) between any two tokens is allowed
es5id: 7.2_A1.4_T2
description: Insert real SPACE between tokens of var x=1
---*/

//CHECK#1
eval("\u0020var x\u0020= 1\u0020");
if (x !== 1) {
  $ERROR('#1: eval("\\u0020var x\\u0020= 1\\u0020"); x === 1. Actual: ' + (x));
}

//CHECK#2
 var x = 1 ;
if (x !== 1) {
  $ERROR('#2:  var x = 1 ; x === 1. Actual: ' + (x));
}
