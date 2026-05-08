#include "test_harness.h"
#include "../src/core/ofxGgmlResult.h"

#include <memory>

OFXGGML_TEST(result_stores_value) {
	ofxGgmlResult<int> result(7);
	OFXGGML_REQUIRE(result.isOk());
	OFXGGML_REQUIRE(result.value() == 7);
}

OFXGGML_TEST(result_stores_error) {
	auto result = ofxGgmlResult<int>::failure("no model", 44);
	OFXGGML_REQUIRE(result.isError());
	OFXGGML_REQUIRE(result.error().message == "no model");
	OFXGGML_REQUIRE(result.error().code == 44);
}

OFXGGML_TEST(result_supports_move_only_values) {
	ofxGgmlResult<std::unique_ptr<int>> result(std::make_unique<int>(3));
	OFXGGML_REQUIRE(result.isOk());
	OFXGGML_REQUIRE(*result.value() == 3);
}
