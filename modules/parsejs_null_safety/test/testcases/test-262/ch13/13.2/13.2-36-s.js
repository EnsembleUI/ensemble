// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 13.2-36-s
description: >
    StrictMode - property named 'arguments' of function objects is not
    configurable
flags: [onlyStrict]
includes: [runTestCase.js]
---*/

function testcase() {
        var funcExpr = function () { "use strict";};
        return ! Object.getOwnPropertyDescriptor(funcExpr, 
                                                  "arguments").configurable;
}
runTestCase(testcase);
