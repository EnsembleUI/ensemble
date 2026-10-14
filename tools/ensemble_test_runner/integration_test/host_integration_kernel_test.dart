// Runs the host shared-kernel contract under Flutter's integration-test
// discovery path. The implementation stays in the focused unit test so the
// contract has one source of truth while this wrapper verifies the real host
// binding/plugin boundary.
import '../test/host_integration_kernel_test.dart' as host_kernel;

void main() => host_kernel.main();
