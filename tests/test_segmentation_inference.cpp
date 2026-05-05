#include "catch2.hpp"
#include "../src/inference/ofxGgmlSegmentationInference.h"
#include "../src/inference/ofxGgmlSamCppAdapters.h"

#include <memory>
#include <string>

TEST_CASE("Segmentation inference initialization", "[segmentation_inference]") {
	ofxGgmlSegmentationInference segmentation;

	SECTION("Default construction") {
		REQUIRE_NOTHROW(ofxGgmlSegmentationInference());
	}

	SECTION("Has default backend") {
		REQUIRE(segmentation.getBackend() != nullptr);
	}
}

TEST_CASE("Segmentation bridge backend creation", "[segmentation_inference]") {
	SECTION("Create generic bridge backend") {
		auto backend = ofxGgmlSegmentationInference::createSegmentationBridgeBackend();
		REQUIRE(backend != nullptr);
		REQUIRE_FALSE(backend->backendName().empty());
	}

	SECTION("Create with custom name") {
		auto backend =
			ofxGgmlSegmentationInference::createSegmentationBridgeBackend(
				{},
				"CustomSegmenter");
		REQUIRE(backend != nullptr);
		REQUIRE(backend->backendName() == "CustomSegmenter");
	}

	SECTION("Create sam.cpp bridge backend") {
		auto backend = ofxGgmlSegmentationInference::createSamCppBridgeBackend();
		REQUIRE(backend != nullptr);
		REQUIRE_FALSE(backend->backendName().empty());
	}
}

TEST_CASE("Segmentation bridge backend configuration", "[segmentation_inference]") {
	auto backend = std::dynamic_pointer_cast<ofxGgmlSegmentationBridgeBackend>(
		ofxGgmlSegmentationInference::createSegmentationBridgeBackend());

	SECTION("Unconfigured by default") {
		REQUIRE_FALSE(backend->isConfigured());
	}

	SECTION("Configured after setting function") {
		backend->setSegmentFunction(
			[](const ofxGgmlSegmentationRequest &) {
				ofxGgmlSegmentationResult result;
				result.success = true;
				return result;
			});
		REQUIRE(backend->isConfigured());
	}
}

TEST_CASE("Segmentation request and result structures", "[segmentation_inference]") {
	SECTION("Request defaults to point prompts") {
		ofxGgmlSegmentationRequest request;
		REQUIRE(request.promptType == ofxGgmlSegmentationPromptType::Point);
		REQUIRE(request.threads == -1);
		REQUIRE(request.returnMultipleMasks);
	}

	SECTION("Point prompt can be populated") {
		ofxGgmlSegmentationPoint point;
		point.x = 12.5f;
		point.y = 32.0f;
		point.positive = false;
		REQUIRE(point.x == 12.5f);
		REQUIRE(point.y == 32.0f);
		REQUIRE_FALSE(point.positive);
	}

	SECTION("Mask can hold image bytes") {
		ofxGgmlSegmentationMask mask;
		mask.maskId = "mask";
		mask.width = 2;
		mask.height = 2;
		mask.pixels = {0, 255, 255, 0};
		REQUIRE(mask.pixels.size() == 4);
		REQUIRE(mask.width == 2);
		REQUIRE(mask.height == 2);
	}
}

TEST_CASE("Segmentation backend setting and mock execution", "[segmentation_inference]") {
	ofxGgmlSegmentationInference segmentation;

	SECTION("Set null backend creates default") {
		segmentation.setBackend(nullptr);
		REQUIRE(segmentation.getBackend() != nullptr);
	}

	SECTION("Unconfigured backend reports an error") {
		const auto result = segmentation.segmentPoint("image.jpg", 10.0f, 20.0f);
		REQUIRE_FALSE(result.success);
		REQUIRE_FALSE(result.error.empty());
	}

	SECTION("Configured backend receives point requests") {
		auto backend = std::dynamic_pointer_cast<ofxGgmlSegmentationBridgeBackend>(
			ofxGgmlSegmentationInference::createSegmentationBridgeBackend());
		backend->setSegmentFunction(
			[](const ofxGgmlSegmentationRequest & request) {
				ofxGgmlSegmentationResult result;
				result.success = true;
				result.imagePath = request.imagePath;
				ofxGgmlSegmentationMask mask;
				mask.maskId = "mock";
				mask.width = 1;
				mask.height = 1;
				mask.pixels = {255};
				result.masks.push_back(mask);
				result.metadata.push_back({
					"pointCount",
					std::to_string(request.points.size())
				});
				return result;
			});
		segmentation.setBackend(backend);

		const auto result = segmentation.segmentPoint(
			"image.jpg",
			10.0f,
			20.0f,
			"sam.bin",
			4);

		REQUIRE(result.success);
		REQUIRE(result.imagePath == "image.jpg");
		REQUIRE(result.masks.size() == 1);
		REQUIRE(result.masks.front().pixels.front() == 255);
		REQUIRE(result.metadata.front().second == "1");
	}
}

TEST_CASE("sam.cpp adapter reports missing integration cleanly", "[segmentation_inference][sam_cpp]") {
	REQUIRE(OFXGGML_HAS_SAMCPP == 0);

	ofxGgmlSegmentationInference segmentation;
	ofxGgmlSamCppAdapters::attachBackend(
		segmentation,
		"/definitely/missing/ofxGgml-test-sam-model.bin");

	ofxGgmlSegmentationRequest request;
	request.imagePath = "image.jpg";
	request.imageWidth = 1;
	request.imageHeight = 1;
	request.imageRgb = {0, 0, 0};
	request.points.push_back({0.0f, 0.0f, true});

	const auto result = segmentation.segment(request);
	REQUIRE_FALSE(result.success);
	REQUIRE(result.backendName == "sam.cpp");
	REQUIRE(result.error.find("sam.cpp headers are not available") != std::string::npos);
}
