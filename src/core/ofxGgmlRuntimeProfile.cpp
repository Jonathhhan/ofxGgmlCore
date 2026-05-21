#include "ofxGgmlRuntimeProfile.h"

#include "ofxGgmlRuntime.h"

#include <algorithm>
#include <string>

namespace {

bool backendMatches(const ofxGgmlDeviceInfo & device, ofxGgmlBackend backend) {
	return backend == ofxGgmlBackend::Auto || device.backend == backend;
}

bool hasAvailableBackend(const std::vector<ofxGgmlDeviceInfo> & devices, ofxGgmlBackend backend) {
	return std::any_of(devices.begin(), devices.end(), [backend](const ofxGgmlDeviceInfo & device) {
		return device.available && device.backend == backend;
	});
}

bool hasRequiredMemory(const std::vector<ofxGgmlDeviceInfo> & devices,
					   ofxGgmlBackend backend,
					   std::size_t bytes) {
	if (bytes == 0) {
		return true;
	}
	return std::any_of(devices.begin(), devices.end(), [backend, bytes](const ofxGgmlDeviceInfo & device) {
		return device.available && backendMatches(device, backend) && device.memoryBytes >= bytes;
	});
}

std::string countMessage(const std::string & label, uint64_t actual, uint64_t expected) {
	return label + " is " + std::to_string(actual) + ", expected at least " +
		std::to_string(expected);
}

void validateModelInfo(const ofxGgmlRuntimeProfile & profile,
					   const ofxGgmlModelInfo & modelInfo,
					   std::vector<std::string> & errors) {
	if (!profile.expectedArchitecture.empty() &&
		modelInfo.architecture != profile.expectedArchitecture) {
		errors.push_back(
			"model architecture is '" + modelInfo.architecture + "', expected '" +
			profile.expectedArchitecture + "'");
	}
	if (profile.minTensorCount > 0 && modelInfo.tensorCount < profile.minTensorCount) {
		errors.push_back(countMessage("model tensor count", modelInfo.tensorCount,
			profile.minTensorCount));
	}
	if (profile.minMetadataCount > 0 && modelInfo.metadataCount < profile.minMetadataCount) {
		errors.push_back(countMessage("model metadata count", modelInfo.metadataCount,
			profile.minMetadataCount));
	}
	if (profile.minLayerCount > 0 && modelInfo.layerCount < profile.minLayerCount) {
		errors.push_back(countMessage("model layer count", modelInfo.layerCount,
			profile.minLayerCount));
	}
	if (profile.minContextLength > 0 && modelInfo.contextLength < profile.minContextLength) {
		errors.push_back(countMessage("model context length", modelInfo.contextLength,
			profile.minContextLength));
	}
}

} // namespace

ofxGgmlRuntimeProfileReport ofxGgmlRuntimeProfileValidator::validate(
	const ofxGgmlRuntimeProfile & profile) const {
	ofxGgmlRuntimeProfileReport report;
	ofxGgmlRuntime runtime;
	bool strictBackendUnavailable = false;
	report.devices = runtime.getDevices();

	if (profile.requireModel && profile.modelPath.empty()) {
		report.errors.push_back("model path is required");
	}

	if (!profile.modelPath.empty()) {
		ofxGgmlModel model;
		auto modelResult = model.inspect(profile.modelPath);
		if (modelResult.isOk()) {
			report.hasModelInfo = true;
			report.modelInfo = modelResult.value();
			validateModelInfo(profile, report.modelInfo, report.errors);
		} else {
			report.errors.push_back(modelResult.error().message);
		}
	}

	if (profile.runtime.preferredBackend != ofxGgmlBackend::Auto &&
		!hasAvailableBackend(report.devices, profile.runtime.preferredBackend)) {
		if (profile.runtime.allowCpuFallback) {
			report.warnings.push_back(
				std::string(ofxGgmlGetBackendName(profile.runtime.preferredBackend)) +
				" backend is unavailable; CPU fallback may be used");
		} else {
			report.errors.push_back(
				std::string(ofxGgmlGetBackendName(profile.runtime.preferredBackend)) +
				" backend is unavailable");
			strictBackendUnavailable = true;
		}
	}

	if (!hasRequiredMemory(report.devices,
			profile.runtime.preferredBackend,
			profile.minDeviceMemoryBytes)) {
		report.errors.push_back("no available device satisfies the minimum memory requirement");
	}

	if (profile.requireRuntimeSetup && !strictBackendUnavailable) {
		auto setupResult = runtime.setup(profile.runtime);
		if (setupResult.isOk()) {
			report.backendName = runtime.getBackendName();
		} else {
			report.errors.push_back(setupResult.error().message);
		}
	}

	report.ready = report.errors.empty();
	return report;
}

ofxGgmlRuntimeProfileReport ofxGgmlValidateRuntimeProfile(
	const ofxGgmlRuntimeProfile & profile) {
	ofxGgmlRuntimeProfileValidator validator;
	return validator.validate(profile);
}
