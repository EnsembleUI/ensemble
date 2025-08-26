// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
es5id: 12.6.4-2
description: >
    The for-in Statement - the values of [[Enumerable]] attributes are
    not considered when determining if a property of a prototype
    object is shadowed by a previous object on the prototype chain
includes: [runTestCase.js]
---*/

function testcase() {
        var proto = {
            prop: "enumerableValue"
        };

        var ConstructFun = function () { };
        ConstructFun.prototype = proto;

        var child = new ConstructFun();

        Object.defineProperty(child, "prop", {
            value: "nonEnumerableValue",
            enumerable: false
        });

        var accessedProp = false;

        for (var p in child) {
            if (p === "prop") {
                accessedProp = true;
            }
        }
        return !accessedProp;
    }
runTestCase(testcase);
