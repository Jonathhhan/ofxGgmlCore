#include "ofxGgmlTextGeneration.h"

#include <chrono>
#include <utility>

ofxGgmlTextBridgeBackend::ofxGgmlTextBridgeBackend(
	GenerateFunction generateFunction,
	std::string displayName)
	: m_generateFunction(std::move(generateFunction))
	, m_displayName(std::move(displayName)) {
}

void ofxGgmlTextBridgeBackend::setGenerateFunction(
	GenerateFunction generateFunction) {
	m_generateFunction = std::move(generateFunction);
}

bool ofxGgmlTextBridgeBackend::isConfigured() const {
	return static_cast<bool>(m_generateFunction);
}

std::string ofxGgmlTextBridgeBackend::backendName() const {
	return m_displayName.empty() ? "TextBridge" : m_displayName;
}

ofxGgmlTextResult ofxGgmlTextBridgeBackend::generate(
	const ofxGgmlTextRequest & request,
	ofxGgmlTextChunkCallback onChunk) const {
	ofxGgmlTextResult result;
	result.backendName = backendName();
	if (!m_generateFunction) {
		result.error =
			"text bridge backend is not configured. Attach a text generation "
			"adapter callback before calling generate().";
		return result;
	}

	const auto started = std::chrono::steady_clock::now();
	result = m_generateFunction(request, onChunk);
	if (result.backendName.empty()) {
		result.backendName = backendName();
	}
	if (result.elapsedMs <= 0.0f) {
		result.elapsedMs = std::chrono::duration<float, std::milli>(
			std::chrono::steady_clock::now() - started).count();
	}
	return result;
}

ofxGgmlTextGenerator::ofxGgmlTextGenerator()
	: m_backend(createTextBridgeBackend()) {
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
	m_backend = backend
		? std::move(backend)
		: createTextBridgeBackend();
}

std::shared_ptr<ofxGgmlTextBackend> ofxGgmlTextGenerator::getBackend() const {
	return m_backend;
}

ofxGgmlTextResult ofxGgmlTextGenerator::generate(
	const ofxGgmlTextRequest & request,
	ofxGgmlTextChunkCallback onChunk) const {
	const auto backend = m_backend
		? m_backend
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
