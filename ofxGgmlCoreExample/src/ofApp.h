#pragma once

#include "ofMain.h"
#include "ofxGgml.h"
#include "ofxImGui.h"

#include <atomic>
#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup() override;
	void update() override;
	void draw() override;
	void exit() override;

private:
	struct BackendJob {
		ofxGgmlBackend requestedBackend = ofxGgmlBackend::Auto;
		bool discoverBackends = false;
		bool preferAccelerator = false;
		bool allowCpuFallback = false;
		int elementCount = 262144;
		int iterationCount = 512;
	};

	struct BackendResult {
		ofxGgmlBackend requestedBackend = ofxGgmlBackend::Auto;
		std::vector<ofxGgmlBackend> availableBackends;
		bool hadError = false;
		bool usedFallback = false;
		std::string activeBackendName = "not run";
		std::vector<std::string> lines;
	};

	class BackendWorker : public ofThread {
	public:
		void start();
		void stop();
		bool submit(BackendJob job);
		bool tryReceive(BackendResult & result);
		bool isBusy() const;

	private:
		void threadedFunction() override;
		BackendResult runJob(const BackendJob & job);

		ofThreadChannel<BackendJob> jobs;
		ofThreadChannel<BackendResult> results;
		std::atomic<bool> busy{ false };
	};

	ofxGgmlBackend getSelectedBackend() const;
	void requestBackendCheck(bool discoverBackends);
	void applyResult(BackendResult result);

	BackendWorker backendWorker;
	ofxImGui::Gui gui;

	std::vector<ofxGgmlBackend> backendOptions;
	std::vector<ofxGgmlBackend> availableBackends;
	int selectedBackendIndex = 0;
	bool allowCpuFallback = false;
	int workloadElements = 262144;
	int workloadIterations = 512;
	bool lastRunHadError = false;
	bool lastRunUsedFallback = false;
	std::string lastRequestedBackendName = "not run";
	std::string lastBackendName = "not run";
	std::vector<std::string> lines;
};
