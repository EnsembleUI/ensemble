// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 11.13.2-29-s
description: >
    Strict Mode - TypeError is thrown if The LeftHandSide of a
    Compound Assignment operator(>>=) is a reference to a data
    property with the attribute value {[[Writable]]:false}
flags: [onlyStrict]
includes: [runTestCase.js]
---*/

function testcase() {
        "use strict";
        var obj = {};
        Object.defineProperty(obj, "prop", {
            value: 10,
            writable: false,
            enumerable: true,
            configurable: true
        });

        try {
            obj.prop >>= 20;
            return false;
        } catch (e) {
            return e instanceof TypeError && obj.prop === 10;
        }
    }
runTestCase(testcase);
