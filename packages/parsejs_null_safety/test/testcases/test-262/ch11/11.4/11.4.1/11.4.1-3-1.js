// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 11.4.1-3-1
description: >
    delete operator returns true when deleting an unresolvable
    reference
includes: [runTestCase.js]
---*/

function testcase() {
  // just cooking up a long/veryLikely unique name
  var d = delete __ES3_1_test_suite_test_11_4_1_3_unique_id_0__;
  if (d === true) {
    return true;
  }
 }
runTestCase(testcase);
