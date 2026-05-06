#pragma once

#include "ofMain.h"
#include "ofxGgmlCompanionWorkflows.h"

#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup();
	void draw();
	void keyPressed(int key);

private:
	void rebuildPreview();
	void preparePrompt();
	void saveAbcSketch();
	void generateWithTextModel();
	void checkAceStep();
	void renderAceStep();
	void appendWrapped(const std::string & label, const std::string & text, size_t width = 112);
	std::string sharedAceStepModelDir() const;

	ofxGgmlMusicGenerator generator;
	ofxGgmlAceStepBridge aceStep;
	ofxGgmlMusicPromptRequest promptRequest;
	ofxGgmlMusicNotationRequest notationRequest;
	ofxGgmlAceStepRequest aceRequest;
	std::string textModelPath;
	std::string completionExecutable = "llama-completion";
	std::string aceStepServerUrl = "http://127.0.0.1:8085";
	std::string preparedPrompt;
	std::string abcSketch;
	std::string status;
	std::vector<std::string> lines;
};
