#include "test_harness.h"
#include "../src/ofxGgmlCore.h"
#include "../src/ofxGgml.h"

OFXGGML_TEST(public_core_header_compiles) {
	OFXGGML_REQUIRE(OFXGGML_VERSION_MAJOR == 1);
	OFXGGML_REQUIRE(OFXGGML_VERSION_MINOR == 0);
	OFXGGML_REQUIRE(OFXGGML_VERSION_PATCH == 1);
	OFXGGML_REQUIRE(std::string(OFXGGML_VERSION_STRING) == "1.0.1");
	OFXGGML_REQUIRE(std::string(ofxGgmlGetBackendName(ofxGgmlBackend::Auto)) == "Auto");
	OFXGGML_REQUIRE(std::string(ofxGgmlGetBackendName(ofxGgmlBackend::CPU)) == "CPU");
	OFXGGML_REQUIRE(std::string(ofxGgmlGetBackendName(ofxGgmlBackend::CUDA)) == "CUDA");
	OFXGGML_REQUIRE(std::string(ofxGgmlGetBackendName(ofxGgmlBackend::Vulkan)) == "Vulkan");
	OFXGGML_REQUIRE(std::string(ofxGgmlGetBackendName(ofxGgmlBackend::Metal)) == "Metal");
	OFXGGML_REQUIRE(std::string(ofxGgmlGetBackendName(ofxGgmlBackend::OpenCL)) == "OpenCL");
}