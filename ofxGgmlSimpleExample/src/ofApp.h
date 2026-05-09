#pragma once

#include "ofMain.h"
#include "ofxGgml.h"

#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;

private:
	ofxGgml runtime;
	ofxGgmlGraph graph;
	std::vector<std::string> lines;
};
