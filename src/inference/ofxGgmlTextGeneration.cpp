#include "ofxGgmlTextGeneration.h"

#include <chrono>
#include <utility>

ofxGgmlTextBridgeBackend::ofxGgmlTextBridgeBackend(
	GenerateFunction generateFunction,
	std::string displayName)
	: generateCallback(std::move(generateFunction))
	, displayName(std::move(displayName)) {
}

void ofxGgmlTextBridgeBackend::setGenerateFunction(
	GenerateFunction generateFunction) {
	generateCallback = std::move(generateFunction);
}

bool ofxGgmlTextBridgeBackend::isConfigured() const {
	return static_cast<bool>(generateCallback);
}

std::string ofxGgmlTextBridgeBackend::getBackendName() const {
	return displayName.empty() ? "TextBridge" : displayName;
}

ofxGgmlTextResult ofxGgmlTextBridgeBackend::generate(
	const ofxGgmlTextRequest & request,
	ofxGgmlTextChunkCallback onChunk) const {
	ofxGgmlTextResult result;
	result.backendName = getBackendName();
	if (!generateCallback) {
		result.error =
			"text bridge backend is not configured. Attach a text generation "
			"adapter callback before calling generate().";
		return result;
	}

	const auto started = std::chrono::steady_clock::now();
	result = generateCallback(request, onChunk);
	if (result.backendName.empty()) {
		result.backendName = getBackendName();
	}
	if (result.elapsedMs <= 0.0f) {
		result.elapsedMs = std::chrono::duration<float, std::milli>(
			std::chrono::steady_clock::now() - started).count();
	}
	return result;
}

ofxGgmlTextGenerator::ofxGgmlTextGenerator()
	: backendPtr(createTextBridgeBackend()) {
}

std::shared_ptr<ofxGgmlTextBackend>
ofxGgmlTextGenerator::createTextBridgeBackend(
	ofxGgmlTextBridgeBackend::GenerateFunction generateFunction,
	const std::string & displayName) {
	return std::make_shared<ofxGgmlTextBridgeBackend>(
		std::move(generateFunction),
		displayName);
}

void ofxGgmlTextGenerator::setBackend(std::shared_ptr<ofxGgmlTextBackend> backend) {
	backendPtr = backend
		? std::move(backend)
		: createTextBridgeBackend();
}

std::shared_ptr<ofxGgmlTextBackend> ofxGgmlTextGenerator::getBackend() const {
	return backendPtr;
}

ofxGgmlTextResult ofxGgmlTextGenerator::generate(
	const ofxGgmlTextRequest & request,
	ofxGgmlTextChunkCallback onChunk) const {
	const auto backend = backendPtr
		? backendPtr
		: createTextBridgeBackend();
	return backend->generate(request, std::move(onChunk));
}

ofxGgmlTextResult ofxGgmlTextGenerator::generate(
	const std::string & prompt,
	const std::string & modelPath,
	const ofxGgmlTextGenerationSettings & settings,
	ofxGgmlTextChunkCallback onChunk) const {
	ofxGgmlTextRequest request;
	request.prompt = prompt;
	request.modelPath = modelPath;
	request.settings = settings;
	return generate(request, std::move(onChunk));
}
