#include "test_harness.h"
#include "../src/core/ofxGgmlRuntimeProfile.h"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string>

namespace {

std::filesystem::path profileTestFilePath(const std::string & name) {
	return std::filesystem::temp_directory_path() / name;
}

void writeU32(std::ostream & output, uint32_t value) {
	output.write(reinterpret_cast<const char *>(&value), sizeof(value));
}

void writeU64(std::ostream & output, uint64_t value) {
	output.write(reinterpret_cast<const char *>(&value), sizeof(value));
}

void writeString(std::ostream & output, const std::string & value) {
	writeU64(output, static_cast<uint64_t>(value.size()));
	output.write(value.data(), static_cast<std::streamsize>(value.size()));
}

void writeProfileTinyGguf(const std::filesystem::path & path, const std::string & architecture) {
	std::ofstream output(path, std::ios::binary);
	output.write("GGUF", 4);
	writeU32(output, 3);
	writeU64(output, 2);
	writeU64(output, 3);
	writeString(output, "general.architecture");
	writeU32(output, 8);
	writeString(output, architecture);
	writeString(output, architecture + ".block_count");
	writeU32(output, 4);
	writeU32(output, 32);
	writeString(output, architecture + ".context_length");
	writeU32(output, 4);
	writeU32(output, 131072);
}

} // namespace

OFXGGML_TEST(runtime_profile_accepts_default_cpu_runtime) {
	ofxGgmlRuntimeProfile profile;

	auto report = ofxGgmlValidateRuntimeProfile(profile);

	OFXGGML_REQUIRE(report.isReady());
	OFXGGML_REQUIRE(report);
	OFXGGML_REQUIRE(report.backendName == "CPU");
	OFXGGML_REQUIRE(!report.devices.empty());
	OFXGGML_REQUIRE(report.errors.empty());
}

OFXGGML_TEST(runtime_profile_can_require_model_path_without_setup) {
	ofxGgmlRuntimeProfile profile;
	profile.requireRuntimeSetup = false;
	profile.requireModel = true;

	auto report = ofxGgmlValidateRuntimeProfile(profile);

	OFXGGML_REQUIRE(!report.isReady());
	OFXGGML_REQUIRE(report.errors.size() == 1);
	OFXGGML_REQUIRE(report.errors[0] == "model path is required");
	OFXGGML_REQUIRE(report.backendName.empty());
}

OFXGGML_TEST(runtime_profile_validates_tiny_gguf_metadata) {
	const auto path = profileTestFilePath("ofxGgml_profile_tiny_model.gguf");
	writeProfileTinyGguf(path, "llama");

	ofxGgmlRuntimeProfile profile;
	profile.modelPath = path.string();
	profile.expectedArchitecture = "llama";
	profile.minTensorCount = 2;
	profile.minMetadataCount = 3;
	profile.minLayerCount = 32;
	profile.minContextLength = 4096;

	auto report = ofxGgmlValidateRuntimeProfile(profile);

	OFXGGML_REQUIRE(report.isReady());
	OFXGGML_REQUIRE(report.hasModelInfo);
	OFXGGML_REQUIRE(report.modelInfo.architecture == "llama");
	OFXGGML_REQUIRE(report.modelInfo.layerCount == 32);
	OFXGGML_REQUIRE(report.modelInfo.contextLength == 131072);

	std::filesystem::remove(path);
}

OFXGGML_TEST(runtime_profile_reports_model_contract_errors) {
	const auto path = profileTestFilePath("ofxGgml_profile_mismatch_model.gguf");
	writeProfileTinyGguf(path, "llama");

	ofxGgmlRuntimeProfile profile;
	profile.requireRuntimeSetup = false;
	profile.modelPath = path.string();
	profile.expectedArchitecture = "clip";
	profile.minContextLength = 200000;

	auto report = ofxGgmlValidateRuntimeProfile(profile);

	OFXGGML_REQUIRE(!report.isReady());
	OFXGGML_REQUIRE(report.hasModelInfo);
	OFXGGML_REQUIRE(report.errors.size() == 2);
	OFXGGML_REQUIRE(report.errors[0] == "model architecture is 'llama', expected 'clip'");
	OFXGGML_REQUIRE(report.errors[1] ==
		"model context length is 131072, expected at least 200000");

	std::filesystem::remove(path);
}
