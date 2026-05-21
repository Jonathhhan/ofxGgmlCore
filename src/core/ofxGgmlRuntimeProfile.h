#pragma once

#include "ofxGgmlTypes.h"

#include "../model/ofxGgmlModel.h"

#include <cstdint>
#include <string>
#include <vector>

struct ofxGgmlRuntimeProfile {
	std::string name;
	ofxGgmlRuntimeSettings runtime;
	bool requireRuntimeSetup = true;
	std::string modelPath;
	bool requireModel = false;
	std::string expectedArchitecture;
	uint64_t minTensorCount = 0;
	uint64_t minMetadataCount = 0;
	uint64_t minLayerCount = 0;
	uint64_t minContextLength = 0;
	std::size_t minDeviceMemoryBytes = 0;
};

struct ofxGgmlRuntimeProfileReport {
	bool ready = false;
	std::string backendName;
	std::vector<ofxGgmlDeviceInfo> devices;
	bool hasModelInfo = false;
	ofxGgmlModelInfo modelInfo;
	std::vector<std::string> notes;
	std::vector<std::string> warnings;
	std::vector<std::string> errors;

	explicit operator bool() const {
		return isReady();
	}

	bool isReady() const {
		return ready;
	}
};

class ofxGgmlRuntimeProfileValidator {
public:
	ofxGgmlRuntimeProfileReport validate(const ofxGgmlRuntimeProfile & profile) const;
};

ofxGgmlRuntimeProfileReport ofxGgmlValidateRuntimeProfile(
	const ofxGgmlRuntimeProfile & profile);
