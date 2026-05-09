#pragma once

#include "ofMain.h"
#include "ofxGgmlText.h"

#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;
	void keyPressed(int key) override;

private:
	void runPrompt();
	void rebuildLines();
	static std::string envValue(const char * name);

	ofxGgmlTextGenerator generator;
	ofxGgmlTextGenerationSettings settings;
	std::string modelPath;
	std::string prompt;
	std::string output;
	std::string status;
	std::vector<std::string> lines;
};
