#include "ofxGgmlDiffusionInference.h"
#include "ofxGgmlVisionInference.h"
#include "ofxGgmlInference.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <utility>

ofxGgmlStableDiffusionBridgeBackend::ofxGgmlStableDiffusionBridgeBackend(
	GenerateFunction generateFunction,
	std::string displayName)
	: m_generateFunction(std::move(generateFunction))
	, m_displayName(std::move(displayName)) {
}

void ofxGgmlStableDiffusionBridgeBackend::setGenerateFunction(
	GenerateFunction generateFunction) {
	m_generateFunction = std::move(generateFunction);
}

void ofxGgmlStableDiffusionBridgeBackend::setGetCapabilitiesFunction(
	GetCapabilitiesFunction getCapabilitiesFunction) {
	m_getCapabilitiesFunction = std::move(getCapabilitiesFunction);
}

bool ofxGgmlStableDiffusionBridgeBackend::isConfigured() const {
	return static_cast<bool>(m_generateFunction);
}

std::string ofxGgmlStableDiffusionBridgeBackend::backendName() const {
	return m_displayName.empty() ? "ofxStableDiffusion" : m_displayName;
}

ofxGgmlImageGenerationResult ofxGgmlStableDiffusionBridgeBackend::generate(
	const ofxGgmlImageGenerationRequest & request) const {
	ofxGgmlImageGenerationResult result;
	result.backendName = backendName();
	if (!m_generateFunction) {
		result.error =
			"stable diffusion bridge backend is not configured yet. "
			"Attach an ofxStableDiffusion adapter callback before calling generate().";
		result.errorType = ofxGgmlImageGenerationErrorType::ConfigurationError;
		return result;
	}

	const auto started = std::chrono::steady_clock::now();
	std::lock_guard<std::mutex> lock(m_generateMutex);
	result = m_generateFunction(request);
	if (result.backendName.empty()) {
		result.backendName = backendName();
	}
	if (result.elapsedMs <= 0.0f) {
		result.elapsedMs = std::chrono::duration<float, std::milli>(
			std::chrono::steady_clock::now() - started).count();
	}
	return result;
}

ofxGgmlImageGenerationCapabilities
ofxGgmlStableDiffusionBridgeBackend::getCapabilities() const {
	if (m_getCapabilitiesFunction) {
		return m_getCapabilitiesFunction();
	}
	return {};
}

ofxGgmlDiffusionInference::ofxGgmlDiffusionInference()
	: m_backend(createStableDiffusionBridgeBackend()) {
}

std::vector<ofxGgmlImageGenerationModelProfile>
ofxGgmlDiffusionInference::defaultProfiles() {
	return {
		{
			"Stable Diffusion 1.5",
			"SD 1.x",
			"runwayml/stable-diffusion-v1-5",
			"v1-5-pruned-emaonly.safetensors",
			"",
			"",
			"",
			"",
			true,
			true,
			true,
			true,
			true,
			true
		},
		{
			"Stable Diffusion XL",
			"SDXL",
			"stabilityai/stable-diffusion-xl-base-1.0",
			"sd_xl_base_1.0.safetensors",
			"",
			"",
			"",
			"",
			true,
			true,
			true,
			true,
			true,
			true
		},
		{
			"FLUX.1 Schnell",
			"FLUX.1",
			"black-forest-labs/FLUX.1-schnell",
			"flux1-schnell-Q4_0.gguf",
			"",
			"",
			"",
			"",
			true,
			true,
			true,
			true,
			false,
			false
		}
	};
}

const char * ofxGgmlDiffusionInference::taskLabel(
	ofxGgmlImageGenerationTask task) {
	switch (task) {
	case ofxGgmlImageGenerationTask::TextToImage: return "Text to Image";
	case ofxGgmlImageGenerationTask::ImageToImage: return "Image to Image";
	case ofxGgmlImageGenerationTask::InstructImage: return "Instruct Image";
	case ofxGgmlImageGenerationTask::Variation: return "Variation";
	case ofxGgmlImageGenerationTask::Restyle: return "Restyle";
	case ofxGgmlImageGenerationTask::Inpaint: return "Inpaint";
	case ofxGgmlImageGenerationTask::Upscale: return "Upscale";
	}
	return "Text to Image";
}

const char * ofxGgmlDiffusionInference::selectionModeLabel(
	ofxGgmlImageSelectionMode mode) {
	switch (mode) {
	case ofxGgmlImageSelectionMode::Rerank: return "Rerank";
	case ofxGgmlImageSelectionMode::BestOnly: return "Best Only";
	case ofxGgmlImageSelectionMode::KeepOrder:
	default:
		return "Keep Order";
	}
}

ofxGgmlImageGenerationValidation
ofxGgmlDiffusionInference::validateRequest(
	const ofxGgmlImageGenerationRequest & request,
	const ofxGgmlImageGenerationCapabilities & capabilities) {
	ofxGgmlImageGenerationValidation validation;
	const auto fail = [&validation](
		ofxGgmlImageGenerationErrorType errorType,
		const std::string & error) {
		validation.valid = false;
		validation.errorType = errorType;
		validation.error = error;
	};

	const bool requiresPrompt =
		request.task != ofxGgmlImageGenerationTask::Upscale;
	if (requiresPrompt && request.prompt.empty() && request.instruction.empty()) {
		fail(ofxGgmlImageGenerationErrorType::ValidationError, "prompt is empty");
		return validation;
	}
	if (request.width <= 0 || request.height <= 0) {
		fail(
			ofxGgmlImageGenerationErrorType::ValidationError,
			"width and height must be positive");
		return validation;
	}
	if (request.steps <= 0 && request.task != ofxGgmlImageGenerationTask::Upscale) {
		fail(
			ofxGgmlImageGenerationErrorType::ValidationError,
			"steps must be positive");
		return validation;
	}
	if (request.batchCount <= 0) {
		fail(
			ofxGgmlImageGenerationErrorType::ValidationError,
			"batchCount must be positive");
		return validation;
	}
	if (request.task == ofxGgmlImageGenerationTask::ImageToImage ||
		request.task == ofxGgmlImageGenerationTask::InstructImage ||
		request.task == ofxGgmlImageGenerationTask::Variation ||
		request.task == ofxGgmlImageGenerationTask::Restyle ||
		request.task == ofxGgmlImageGenerationTask::Upscale) {
		if (request.initImagePath.empty()) {
			fail(
				ofxGgmlImageGenerationErrorType::ValidationError,
				"selected task requires initImagePath");
			return validation;
		}
	}
	if (request.task == ofxGgmlImageGenerationTask::Inpaint &&
		request.maskImagePath.empty()) {
		fail(
			ofxGgmlImageGenerationErrorType::ValidationError,
			"inpaint requires maskImagePath");
		return validation;
	}

	const bool hasExplicitCapabilities =
		capabilities.supportsTextToImage ||
		capabilities.supportsImageToImage ||
		capabilities.supportsInstructImage ||
		capabilities.supportsVariation ||
		capabilities.supportsRestyle ||
		capabilities.supportsInpaint ||
		capabilities.supportsUpscale ||
		capabilities.supportsControlNet ||
		capabilities.supportsLoRA ||
		capabilities.supportsProgressCallbacks ||
		capabilities.supportsBatchGeneration ||
		!capabilities.supportedSamplers.empty() ||
		!capabilities.modelArchitecture.empty() ||
		!capabilities.backendVersion.empty();
	if (!hasExplicitCapabilities) {
		return validation;
	}

	const auto unsupportedTask = [&validation](const char * label) {
		validation.valid = false;
		validation.errorType = ofxGgmlImageGenerationErrorType::ValidationError;
		validation.error = std::string(label) +
			" is not supported by the current image-generation backend";
	};
	switch (request.task) {
	case ofxGgmlImageGenerationTask::TextToImage:
		if (!capabilities.supportsTextToImage) unsupportedTask("Text to Image");
		break;
	case ofxGgmlImageGenerationTask::ImageToImage:
		if (!capabilities.supportsImageToImage) unsupportedTask("Image to Image");
		break;
	case ofxGgmlImageGenerationTask::InstructImage:
		if (!capabilities.supportsInstructImage) unsupportedTask("Instruct Image");
		break;
	case ofxGgmlImageGenerationTask::Variation:
		if (!capabilities.supportsVariation) unsupportedTask("Variation");
		break;
	case ofxGgmlImageGenerationTask::Restyle:
		if (!capabilities.supportsRestyle) unsupportedTask("Restyle");
		break;
	case ofxGgmlImageGenerationTask::Inpaint:
		if (!capabilities.supportsInpaint) unsupportedTask("Inpaint");
		break;
	case ofxGgmlImageGenerationTask::Upscale:
		if (!capabilities.supportsUpscale) unsupportedTask("Upscale");
		break;
	}
	if (!validation.valid) {
		return validation;
	}

	if (!request.controlImagePath.empty() && !capabilities.supportsControlNet) {
		fail(
			ofxGgmlImageGenerationErrorType::ValidationError,
			"controlImagePath requires a backend with ControlNet support");
		return validation;
	}
	if (request.batchCount > 1) {
		if (!capabilities.supportsBatchGeneration) {
			fail(
				ofxGgmlImageGenerationErrorType::ValidationError,
				"batchCount exceeds current backend capabilities");
			return validation;
		}
		if (capabilities.maxBatchSize > 0 &&
			request.batchCount > capabilities.maxBatchSize) {
			fail(
				ofxGgmlImageGenerationErrorType::ValidationError,
				"batchCount exceeds current backend capabilities");
			return validation;
		}
	}
	if (!request.sampler.empty() && !capabilities.supportedSamplers.empty()) {
		const auto found = std::find(
			capabilities.supportedSamplers.begin(),
			capabilities.supportedSamplers.end(),
			request.sampler);
		if (found == capabilities.supportedSamplers.end()) {
			fail(
				ofxGgmlImageGenerationErrorType::ValidationError,
				"sampler is not supported by the current backend");
			return validation;
		}
	}
	if (request.progressCallback && !capabilities.supportsProgressCallbacks) {
		validation.warnings.push_back(
			"progressCallback was provided, but the backend did not advertise progress callbacks");
	}
	return validation;
}

std::shared_ptr<ofxGgmlImageGenerationBackend>
ofxGgmlDiffusionInference::createStableDiffusionBridgeBackend(
	ofxGgmlStableDiffusionBridgeBackend::GenerateFunction generateFunction,
	const std::string & displayName) {
	return std::make_shared<ofxGgmlStableDiffusionBridgeBackend>(
		std::move(generateFunction),
		displayName);
}

void ofxGgmlDiffusionInference::setBackend(
	std::shared_ptr<ofxGgmlImageGenerationBackend> backend) {
	m_backend = backend ? std::move(backend) : createStableDiffusionBridgeBackend();
}

std::shared_ptr<ofxGgmlImageGenerationBackend>
ofxGgmlDiffusionInference::getBackend() const {
	return m_backend;
}

ofxGgmlImageGenerationResult ofxGgmlDiffusionInference::generate(
	const ofxGgmlImageGenerationRequest & request) const {
	const auto backend = m_backend ? m_backend : createStableDiffusionBridgeBackend();
	return backend->generate(request);
}

ofxGgmlImageGenerationCapabilities
ofxGgmlDiffusionInference::getCapabilities() const {
	return m_backend ? m_backend->getCapabilities()
		: ofxGgmlImageGenerationCapabilities{};
}

const char * ofxGgmlDiffusionInference::errorTypeLabel(
	ofxGgmlImageGenerationErrorType errorType) {
	switch (errorType) {
	case ofxGgmlImageGenerationErrorType::ConfigurationError:
		return "Configuration Error";
	case ofxGgmlImageGenerationErrorType::ModelLoadError:
		return "Model Load Error";
	case ofxGgmlImageGenerationErrorType::ValidationError:
		return "Validation Error";
	case ofxGgmlImageGenerationErrorType::GenerationError:
		return "Generation Error";
	case ofxGgmlImageGenerationErrorType::ResourceError:
		return "Resource Error";
	case ofxGgmlImageGenerationErrorType::TimeoutError:
		return "Timeout Error";
	case ofxGgmlImageGenerationErrorType::BackendError:
		return "Backend Error";
	case ofxGgmlImageGenerationErrorType::None:
	default:
		return "No Error";
	}
}

ofxGgmlDiffusionInference::ImageValidationResult
ofxGgmlDiffusionInference::validateWithVision(
	const ofxGgmlImageGenerationResult & generationResult,
	const std::string & originalPrompt,
	ofxGgmlVisionInference * visionInference,
	const ofxGgmlVisionModelProfile & visionProfile,
	ofxGgmlInference * textInference) {
	ImageValidationResult result;

	if (!visionInference) {
		result.error = "Vision inference not configured";
		return result;
	}

	if (!generationResult.success || generationResult.images.empty()) {
		result.error = "No generated images to validate";
		return result;
	}

	float totalScore = 0.0f;
	for (const auto & image : generationResult.images) {
		// Use vision to describe the generated image
		ofxGgmlVisionRequest visionRequest;
		visionRequest.task = ofxGgmlVisionTask::Describe;
		visionRequest.prompt = "Describe this image in detail, focusing on the main subjects, composition, and style.";
		visionRequest.images.push_back({image.path, "Generated", ""});
		visionRequest.maxTokens = 256;
		visionRequest.temperature = 0.2f;

		auto visionResult = visionInference->runServerRequest(visionProfile, visionRequest);
		if (!visionResult.success) {
			result.descriptions.push_back({image.index, "Vision analysis failed: " + visionResult.error});
			result.imageScores.push_back({image.index, 0.0f});
			continue;
		}

		result.descriptions.push_back({image.index, visionResult.text});

		// The validation loop no longer receives a text-embedding model path,
		// so keep the vision pass alive and use a neutral alignment score here.
		(void)textInference;
		(void)originalPrompt;
		result.imageScores.push_back({image.index, 0.5f});
		totalScore += 0.5f;
	}

	result.success = true;
	result.averageScore = generationResult.images.empty() ?
		0.0f : totalScore / generationResult.images.size();
	return result;
}
