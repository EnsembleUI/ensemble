// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 11.4.7-4-1
description: -"" should be zero
includes: [runTestCase.js]
---*/

function testcase() {
  return -"" === 0;
 }
runTestCase(testcase);
