// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 7.6.1-18-s
description: >
    7.6 - SyntaxError expected: reserved words used as Identifier
    Names in UTF8: l\u0065t (let)
flags: [onlyStrict]
includes: [runTestCase.js]
---*/

function testcase() {        
        "use strict";

        try {
            eval("var l\u0065t = 123;");
            return false;
        } catch (e) {
            return e instanceof SyntaxError;
        }
}
runTestCase(testcase);
