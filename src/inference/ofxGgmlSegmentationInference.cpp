#include "ofxGgmlSegmentationInference.h"

#include <chrono>
#include <utility>

ofxGgmlSegmentationBridgeBackend::ofxGgmlSegmentationBridgeBackend(
	SegmentFunction segmentFunction,
	std::string displayName)
	: segmentCallback(std::move(segmentFunction))
	, displayName(std::move(displayName)) {
}

void ofxGgmlSegmentationBridgeBackend::setSegmentFunction(
	SegmentFunction segmentFunction) {
	segmentCallback = std::move(segmentFunction);
}

bool ofxGgmlSegmentationBridgeBackend::isConfigured() const {
	return static_cast<bool>(segmentCallback);
}

std::string ofxGgmlSegmentationBridgeBackend::getBackendName() const {
	return displayName.empty() ? "SegmentationBridge" : displayName;
}

ofxGgmlSegmentationResult ofxGgmlSegmentationBridgeBackend::segment(
	const ofxGgmlSegmentationRequest & request) const {
	ofxGgmlSegmentationResult result;
	result.backendName = getBackendName();
	result.imagePath = request.imagePath;
	if (!segmentCallback) {
		result.error =
			"segmentation bridge backend is not configured. Attach a "
			"segmentation adapter callback before calling segment().";
		return result;
	}

	const auto started = std::chrono::steady_clock::now();
	result = segmentCallback(request);
	if (result.backendName.empty()) {
		result.backendName = getBackendName();
	}
	if (result.imagePath.empty()) {
		result.imagePath = request.imagePath;
	}
	if (result.elapsedMs <= 0.0f) {
		result.elapsedMs = std::chrono::duration<float, std::milli>(
			std::chrono::steady_clock::now() - started).count();
	}
	return result;
}

ofxGgmlSegmentationInference::ofxGgmlSegmentationInference()
	: backendPtr(createSegmentationBridgeBackend()) {
}

std::shared_ptr<ofxGgmlSegmentationBackend>
ofxGgmlSegmentationInference::createSegmentationBridgeBackend(
	ofxGgmlSegmentationBridgeBackend::SegmentFunction segmentFunction,
	const std::string & displayName) {
	return std::make_shared<ofxGgmlSegmentationBridgeBackend>(
		std::move(segmentFunction),
		displayName);
}

void ofxGgmlSegmentationInference::setBackend(
	std::shared_ptr<ofxGgmlSegmentationBackend> backend) {
	backendPtr = backend
		? std::move(backend)
		: createSegmentationBridgeBackend();
}

std::shared_ptr<ofxGgmlSegmentationBackend>
ofxGgmlSegmentationInference::getBackend() const {
	return backendPtr;
}

ofxGgmlSegmentationResult ofxGgmlSegmentationInference::segment(
	const ofxGgmlSegmentationRequest & request) const {
	const auto backend = backendPtr
		? backendPtr
		: createSegmentationBridgeBackend();
	return backend->segment(request);
}

ofxGgmlSegmentationResult ofxGgmlSegmentationInference::segmentPoint(
	const std::string & imagePath,
	float x,
	float y,
	const std::string & modelPath,
	int threads) const {
	ofxGgmlSegmentationRequest request;
	request.promptType = ofxGgmlSegmentationPromptType::Point;
	request.imagePath = imagePath;
	request.modelPath = modelPath;
	request.threads = threads;
	request.points.push_back({ x, y, true });
	return segment(request);
}
