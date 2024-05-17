// Copyright (c) 2012 Ecma International.  All rights reserved.
// Ecma International makes this code available under the terms and conditions set
// forth on http://hg.ecmascript.org/tests/test262/raw-file/tip/LICENSE (the
// "Use Terms").   Any redistribution of this code must retain the above
// copyright and this notice and otherwise comply with the Use Terms.

/*---
info: >
    Refer 11.1.5; 
    The production
    PropertyNameAndValueList :  PropertyNameAndValueList , PropertyAssignment
    4. If previous is not undefined then throw a SyntaxError exception if any of the following conditions are true
    c.IsAccessorDescriptor(previous) is true and IsDataDescriptor(propId.descriptor) is true.
es5id: 11.1.5_4-4-c-2
description: >
    Object literal - SyntaxError if a set accessor property definition
    is followed by a data property definition with the same name
includes: [runTestCase.js]
---*/

function testcase() {
  try
  {
    eval("({set foo(x){}, foo : 1});");
    return false;
  }
  catch(e)
  {
    return e instanceof SyntaxError;
  }
 }
runTestCase(testcase);
