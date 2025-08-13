// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 12.2.1-35-s
description: "'for(var eval = 42 in ...) {...}' throws SyntaxError in strict mode"
flags: [onlyStrict]
includes: [runTestCase.js]
---*/

function testcase() {
  'use strict';

  try {
    eval('for (var eval = 42 in null) {};');
    return false;
  }
  catch (e) {
    return (e instanceof SyntaxError);
  }
 }
runTestCase(testcase);
