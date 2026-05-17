#pragma once

#include "../core/ofxGgmlResult.h"

#include <cstdint>
#include <string>

struct ofxGgmlModelInfo {
	std::string path;
	std::string architecture;
	uint64_t tensorCount = 0;
	uint64_t metadataCount = 0;
	uint64_t layerCount = 0;
};

class ofxGgmlModel {
public:
	ofxGgmlResult<ofxGgmlModelInfo> inspect(const std::string & path) const;
};
