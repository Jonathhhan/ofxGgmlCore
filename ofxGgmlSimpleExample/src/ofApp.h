#pragma once

#include "ofMain.h"
#include "ofxGgml.h"
#include "ofxImGui.h"

#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;

private:
	ofxGgml runtime;
	ofxGgmlGraph graph;
	ofxImGui::Gui gui;
	std::vector<std::string> lines;
};
