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
	OFXGGML_REQUIRE(result.error().getDiagnosticCode() == ofxGgmlDiagnosticCode::Unknown);
	OFXGGML_REQUIRE(std::string(result.error().getCodeName()) == "unknown");
}

OFXGGML_TEST(result_supports_structured_diagnostic_codes) {
	auto result = ofxGgmlResult<int>::failure(
		"backend unavailable",
		ofxGgmlDiagnosticCode::BackendUnavailable);

	OFXGGML_REQUIRE(result.isError());
	OFXGGML_REQUIRE(result.error().code ==
		ofxGgmlToDiagnosticCode(ofxGgmlDiagnosticCode::BackendUnavailable));
	OFXGGML_REQUIRE(result.error().getDiagnosticCode() ==
		ofxGgmlDiagnosticCode::BackendUnavailable);
	OFXGGML_REQUIRE(std::string(result.error().getCodeName()) == "backend-unavailable");
}

OFXGGML_TEST(void_result_supports_structured_diagnostic_codes) {
	auto result = ofxGgmlResult<void>::failure(
		"runtime setup failed",
		ofxGgmlDiagnosticCode::RuntimeSetupFailed);

	OFXGGML_REQUIRE(result.isError());
	OFXGGML_REQUIRE(result.error().getDiagnosticCode() ==
		ofxGgmlDiagnosticCode::RuntimeSetupFailed);
}

OFXGGML_TEST(result_supports_move_only_values) {
	ofxGgmlResult<std::unique_ptr<int>> result(std::make_unique<int>(3));
	OFXGGML_REQUIRE(result.isOk());
	OFXGGML_REQUIRE(*result.value() == 3);
}
