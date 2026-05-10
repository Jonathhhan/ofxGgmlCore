#pragma once

#include "ofMain.h"
#include "ofxGgmlText.h"
#include "ofxImGui.h"

#include <mutex>
#include <string>
#include <thread>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void draw() override;
	void keyPressed(int key) override;
	void exit() override;

private:
	void startEmbedding();
	void runEmbeddingWorker();
	void configureGenerator();

	static std::string envValue(const char * name);
	static std::string normalizeEnvText(const std::string & text);
	static std::string embeddingPreview(const std::vector<float> & values);

	ofxGgmlEmbeddingGenerator generator;
	ofxGgmlEmbeddingSettings settings;
	ofxImGui::Gui gui;

	std::string input;
	std::string inputEdit;
	std::string status;
	std::string error;
	std::vector<float> embedding;

	std::thread worker;
	std::mutex stateMutex;
	bool running = false;
};
