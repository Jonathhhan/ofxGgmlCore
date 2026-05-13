#pragma once

#include "ofMain.h"
#include "ofxGgml.h"
#include "ofxImGui.h"

#include <vector>
#include <string>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;

private:
	void configureRuntime(ofxGgmlBackend backend);
	void runComputation();
	void runBenchmark(std::size_t elementCount, int iterationCount);

	ofxGgml runtime;
	ofxGgmlGraph graph;
	ofxImGui::Gui gui;
	std::vector<std::string> lines;
	int selectedBackendIndex = 0;
	int elementCount = 1 << 20;
	int iterationCount = 64;
	bool allowCpuFallback = true;
	std::string lastComputeTime;
	std::string lastThroughput;
	bool runtimeReady = false;
};
