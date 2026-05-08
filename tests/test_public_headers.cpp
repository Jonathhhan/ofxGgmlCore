#include "test_harness.h"
#include "../src/ofxGgmlCore.h"

OFXGGML_TEST(public_core_header_compiles) {
	OFXGGML_REQUIRE(OFXGGML_VERSION_MAJOR == 2);
}
