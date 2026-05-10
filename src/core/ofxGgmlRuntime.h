#pragma once

#include "ofxGgmlResult.h"
#include "ofxGgmlTypes.h"

#include <memory>
#include <string>
#include <vector>

class ofxGgmlGraph;
class ofxGgmlTensor;

class ofxGgmlRuntime {
public:
	ofxGgmlRuntime();
	~ofxGgmlRuntime();

	ofxGgmlRuntime(const ofxGgmlRuntime &) = delete;
	ofxGgmlRuntime & operator=(const ofxGgmlRuntime &) = delete;
	ofxGgmlRuntime(ofxGgmlRuntime &&) noexcept;
	ofxGgmlRuntime & operator=(ofxGgmlRuntime &&) noexcept;

	ofxGgmlResult<void> setup(const ofxGgmlRuntimeSettings & settings = {});
	void close();

	bool isReady() const;
	ofxGgmlRuntimeState getState() const;
	std::string getBackendName() const;
	std::vector<ofxGgmlDeviceInfo> listDevices() const;

	ofxGgmlResult<void> allocate(ofxGgmlGraph & graph);
	ofxGgmlComputeResult compute(ofxGgmlGraph & graph);
	ofxGgmlResult<void> setData(ofxGgmlTensor tensor, const void * data, std::size_t bytes);
	ofxGgmlResult<void> getData(ofxGgmlTensor tensor, void * data, std::size_t bytes);

private:
	struct Impl;
	std::unique_ptr<Impl> impl;
};

using ofxGgml = ofxGgmlRuntime;
