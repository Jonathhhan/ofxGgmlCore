#pragma once

#include "ofxGgmlSegmentationInference.h"

#include <chrono>
#include <memory>
#include <mutex>
#include <string>
#include <thread>
#include <utility>
#include <vector>

#if defined(OFXGGML_ENABLE_SAMCPP_ADAPTER) && defined(__has_include)
#if __has_include("sam.h")
#define OFXGGML_HAS_SAMCPP 1
#include "sam.h"
#else
#define OFXGGML_HAS_SAMCPP 0
#endif
#else
#define OFXGGML_HAS_SAMCPP 0
#endif

namespace ofxGgmlSamCppAdapters {

struct RuntimeOptions {
	int threads = -1;
	int seed = -1;
	int maskOnValue = 255;
	int maskOffValue = 0;
};

inline int resolveThreadCount(const RuntimeOptions & options) {
	if (options.threads > 0) {
		return options.threads;
	}
	const unsigned int detected = std::thread::hardware_concurrency();
	return detected > 0 ? static_cast<int>(detected) : 4;
}

#if OFXGGML_HAS_SAMCPP

using ModelHandle = std::shared_ptr<sam_state>;

inline ModelHandle manageModelHandle(ModelHandle model) {
	if (!model) {
		return {};
	}
	return ModelHandle(
		model.get(),
		[model = std::move(model)](sam_state * state) mutable {
			if (state) {
				sam_deinit(*state);
			}
			model.reset();
		});
}

inline ModelHandle loadModel(
	const std::string & modelPath,
	const RuntimeOptions & options = {},
	std::string * error = nullptr) {
	if (modelPath.empty()) {
		if (error) {
			*error = "sam.cpp model path is empty";
		}
		return {};
	}

	sam_params params;
	params.model = modelPath;
	params.n_threads = resolveThreadCount(options);
	params.seed = options.seed;
	auto model = sam_load_model(params);
	if (!model) {
		if (error) {
			*error = "failed to load sam.cpp model: " + modelPath;
		}
		return {};
	}
	return manageModelHandle(std::move(model));
}

inline bool fillSamImage(
	const ofxGgmlSegmentationRequest & request,
	sam_image_u8 & image,
	std::string * error = nullptr) {
	if (request.imageWidth <= 0 || request.imageHeight <= 0) {
		if (error) {
			*error = "sam.cpp adapter requires imageWidth and imageHeight";
		}
		return false;
	}
	const size_t expectedSize =
		static_cast<size_t>(request.imageWidth) *
		static_cast<size_t>(request.imageHeight) *
		3u;
	if (request.imageRgb.size() != expectedSize) {
		if (error) {
			*error =
				"sam.cpp adapter requires RGB image data sized imageWidth * imageHeight * 3";
		}
		return false;
	}
	image.nx = request.imageWidth;
	image.ny = request.imageHeight;
	image.data.assign(request.imageRgb.begin(), request.imageRgb.end());
	return true;
}

inline ofxGgmlSegmentationResult segmentWithModel(
	const ModelHandle & model,
	const ofxGgmlSegmentationRequest & request,
	const RuntimeOptions & options = {},
	const std::string & modelPath = {}) {
	ofxGgmlSegmentationResult result;
	result.backendName = "sam.cpp";
	result.imagePath = request.imagePath;
	if (!model) {
		result.error = "sam.cpp model is not loaded";
		return result;
	}
	if (request.points.empty()) {
		result.error = "sam.cpp adapter requires at least one point prompt";
		return result;
	}
	if (!request.points.front().positive) {
		result.error = "sam.cpp adapter currently supports positive point prompts only";
		return result;
	}

	sam_image_u8 image;
	if (!fillSamImage(request, image, &result.error)) {
		return result;
	}

	const auto started = std::chrono::steady_clock::now();
	const int threads = request.threads > 0
		? request.threads
		: resolveThreadCount(options);
	if (!sam_compute_embd_img(image, threads, *model)) {
		result.error = "sam.cpp failed to compute image embeddings";
		return result;
	}

	const auto & point = request.points.front();
	const auto masks = sam_compute_masks(
		image,
		threads,
		{point.x, point.y},
		*model,
		options.maskOnValue,
		options.maskOffValue);
	if (masks.empty()) {
		result.error = "sam.cpp did not produce any masks";
		return result;
	}

	const size_t maskCount = request.returnMultipleMasks ? masks.size() : 1u;
	for (size_t i = 0; i < maskCount; ++i) {
		ofxGgmlSegmentationMask mask;
		mask.maskId = "mask-" + std::to_string(i);
		mask.width = masks[i].nx;
		mask.height = masks[i].ny;
		mask.pixels = masks[i].data;
		mask.metadata.push_back({"prompt", "point"});
		mask.metadata.push_back({"pointX", std::to_string(point.x)});
		mask.metadata.push_back({"pointY", std::to_string(point.y)});
		result.masks.push_back(std::move(mask));
	}

	result.success = true;
	result.elapsedMs = std::chrono::duration<float, std::milli>(
		std::chrono::steady_clock::now() - started).count();
	result.metadata.push_back({"backend", "sam.cpp"});
	result.metadata.push_back({"threads", std::to_string(threads)});
	if (!modelPath.empty()) {
		result.metadata.push_back({"modelPath", modelPath});
	}
	return result;
}

inline std::shared_ptr<ofxGgmlSegmentationBackend> createBackend(
	ModelHandle model,
	const RuntimeOptions & options = {},
	const std::string & modelPath = {},
	const std::string & displayName = "sam.cpp") {
	auto mutex = std::make_shared<std::mutex>();
	return ofxGgmlSegmentationInference::createSamCppBridgeBackend(
		[model, options, modelPath, mutex](
			const ofxGgmlSegmentationRequest & request) {
			std::lock_guard<std::mutex> lock(*mutex);
			return segmentWithModel(model, request, options, modelPath);
		},
		displayName);
}

inline std::shared_ptr<ofxGgmlSegmentationBackend> createBackend(
	const std::string & modelPath,
	const RuntimeOptions & options = {},
	const std::string & displayName = "sam.cpp") {
	std::string error;
	const auto model = loadModel(modelPath, options, &error);
	if (!model) {
		return ofxGgmlSegmentationInference::createSamCppBridgeBackend(
			[error, modelPath](const ofxGgmlSegmentationRequest & request) {
				ofxGgmlSegmentationResult result;
				result.backendName = "sam.cpp";
				result.imagePath = request.imagePath;
				result.error = error.empty()
					? "failed to load sam.cpp model: " + modelPath
					: error;
				return result;
			},
			displayName);
	}
	return createBackend(model, options, modelPath, displayName);
}

inline void attachBackend(
	ofxGgmlSegmentationInference & inference,
	ModelHandle model,
	const RuntimeOptions & options = {},
	const std::string & modelPath = {},
	const std::string & displayName = "sam.cpp") {
	inference.setBackend(createBackend(model, options, modelPath, displayName));
}

inline void attachBackend(
	ofxGgmlSegmentationInference & inference,
	const std::string & modelPath,
	const RuntimeOptions & options = {},
	const std::string & displayName = "sam.cpp") {
	inference.setBackend(createBackend(modelPath, options, displayName));
}

#else

inline std::shared_ptr<ofxGgmlSegmentationBackend> createBackend(
	const std::string & modelPath,
	const RuntimeOptions & = {},
	const std::string & displayName = "sam.cpp") {
	return ofxGgmlSegmentationInference::createSamCppBridgeBackend(
		[modelPath](const ofxGgmlSegmentationRequest & request) {
			ofxGgmlSegmentationResult result;
			result.backendName = "sam.cpp";
			result.imagePath = request.imagePath;
			result.error =
				"sam.cpp headers are not available. Add sam.cpp headers and "
				"link the matching sam.cpp library before using model: " + modelPath;
			return result;
		},
		displayName);
}

inline void attachBackend(
	ofxGgmlSegmentationInference & inference,
	const std::string & modelPath,
	const RuntimeOptions & options = {},
	const std::string & displayName = "sam.cpp") {
	inference.setBackend(createBackend(modelPath, options, displayName));
}

#endif

} // namespace ofxGgmlSamCppAdapters
