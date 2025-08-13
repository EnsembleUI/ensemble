// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 7.6.1.2-9-s
description: >
    Strict Mode - SyntaxError is thrown when FutureReservedWord
    'static' occurs in strict mode code
flags: [onlyStrict]
includes: [runTestCase.js]
---*/

function testcase() {
        "use strict";

        try {
            eval("var static = 1;");
            return false;
        } catch (e) {
            return e instanceof SyntaxError;
        }
}
runTestCase(testcase);
