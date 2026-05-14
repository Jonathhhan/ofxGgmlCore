#pragma once

#include "ofMain.h"
#include "ofxGgml.h"
#include "ofxImGui.h"

#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;

private:
	ofxGgmlBackend getSelectedBackend() const;
	void runBackendCheck();

	ofxGgml runtime;
	ofxGgmlGraph graph;
	ofxImGui::Gui gui;

	std::vector<ofxGgmlBackend> backendOptions;
	int selectedBackendIndex = 0;
	bool allowCpuFallback = true;
	int workloadElements = 32768;
	int workloadIterations = 256;
	bool lastRunHadError = false;
	std::string lastBackendName = "not run";
	std::vector<std::string> lines;
};
