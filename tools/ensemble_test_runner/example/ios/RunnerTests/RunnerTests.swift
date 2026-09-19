// Empty Swift compilation unit for the otherwise Objective-C RunnerTests
// target. On Xcode 26+, linking Swift pods (e.g. cloud_functions,
// firebase_app_check) into a pure-ObjC test bundle fails with
// `__swift_FORCE_LOAD_$_swiftCompatibility56` unless the test target itself
// participates in Swift linking. See flutter/flutter#175905.
