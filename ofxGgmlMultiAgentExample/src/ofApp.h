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
	void configureAgents();
	void runBenchmark();

	ofxGgml runtime;
	ofxGgmlGraph graph;
	ofxImGui::Gui gui;
	std::vector<std::string> lines;
};
