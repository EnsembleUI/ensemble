// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
info: >
    Refer 12.6.3; 
    The production 
    IterationStatement : for ( var VariableDeclarationListNoIn ; Expressionopt ; Expressionopt ) Statement
    is evaluated as follows:
es5id: 12.6.3_2-3-a-ii-7
description: >
    The for Statement - (normal, V, empty) will be returned when first
    Expression is a String object (value is empty string)
includes: [runTestCase.js]
---*/

function testcase() {
        var accessed = false;
        var strObj = new String("");
        for (var i = 0; strObj;) {
            accessed = true;
            break;
        }
        return accessed;
    }
runTestCase(testcase);
