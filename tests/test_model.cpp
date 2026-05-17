#include "test_harness.h"
#include "../src/model/ofxGgmlModel.h"

#include <cstdint>
#include <filesystem>
#include <fstream>
#include <string>

namespace {
std::filesystem::path testFilePath(const std::string & name) {
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

void writeTinyGguf(const std::filesystem::path & path, const std::string & architecture) {
	std::ofstream output(path, std::ios::binary);
	output.write("GGUF", 4);
	writeU32(output, 3);
	writeU64(output, 2);
	writeU64(output, 2);
	writeString(output, "general.architecture");
	writeU32(output, 8);
	writeString(output, architecture);
	writeString(output, architecture + ".block_count");
	writeU32(output, 4);
	writeU32(output, 32);
}
}

OFXGGML_TEST(model_rejects_empty_path) {
	ofxGgmlModel model;
	auto result = model.inspect("");

	OFXGGML_REQUIRE(result.isError());
	OFXGGML_REQUIRE(result.error().message == "model path is empty");
}

OFXGGML_TEST(model_rejects_missing_file) {
	const auto path = testFilePath("ofxGgml_missing_test_model.gguf");
	std::filesystem::remove(path);

	ofxGgmlModel model;
	auto result = model.inspect(path.string());

	OFXGGML_REQUIRE(result.isError());
}

OFXGGML_TEST(model_rejects_invalid_gguf_file) {
	const auto path = testFilePath("ofxGgml_invalid_test_model.gguf");
	{
		std::ofstream output(path, std::ios::binary);
		output << "not gguf";
	}

	ofxGgmlModel model;
	auto result = model.inspect(path.string());

	OFXGGML_REQUIRE(result.isError());
	std::filesystem::remove(path);
}

OFXGGML_TEST(model_reads_tiny_gguf_metadata) {
	const auto path = testFilePath("ofxGgml_tiny_test_model.gguf");
	writeTinyGguf(path, "llama");

	ofxGgmlModel model;
	auto result = model.inspect(path.string());

	OFXGGML_REQUIRE(result.isOk());
	OFXGGML_REQUIRE(result.value().path == path.string());
	OFXGGML_REQUIRE(result.value().architecture == "llama");
	OFXGGML_REQUIRE(result.value().tensorCount == 2);
	OFXGGML_REQUIRE(result.value().metadataCount == 2);
	OFXGGML_REQUIRE(result.value().layerCount == 32);

	std::filesystem::remove(path);
}
