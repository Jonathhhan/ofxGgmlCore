#pragma once

#include "ofMain.h"
#include "ofxGgml.h"

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;

private:
	std::string status;
};
