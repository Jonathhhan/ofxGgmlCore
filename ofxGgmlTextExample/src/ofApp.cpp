#include "ofApp.h"

#include <cstdlib>
#include <memory>
#include <sstream>

namespace {

std::vector<std::string> wrapText(const std::string & text, std::size_t width) {
	std::vector<std::string> wrapped;
	std::istringstream words(text);
	std::string word;
	std::string line;
	while (words >> word) {
		const std::string next = line.empty() ? word : line + " " + word;
		if (next.size() > width && !line.empty()) {
			wrapped.push_back(line);
			line = word;
		} else {
			line = next;
		}
	}
	if (!line.empty()) {
		wrapped.push_back(line);
	}
	return wrapped;
}

} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml text example");
	ofBackground(12);

	settings.executablePath = envValue("OFXGGML_LLAMA_CLI");
	modelPath = envValue("OFXGGML_TEXT_MODEL");
	prompt = "Write one concise sentence about local inference in openFrameworks.";

	generator.setBackend(std::make_shared<ofxGgmlLlamaCliTextBackend>());
	runPrompt();
}

void ofApp::draw() {
	ofSetColor(240);
	int y = 36;
	for (const auto & line : lines) {
		ofDrawBitmapString(line, 32, y);
		y += 22;
	}
}

void ofApp::keyPressed(int key) {
	if (key == 'r' || key == 'R') {
		runPrompt();
	}
}

void ofApp::runPrompt() {
	output.clear();
	if (settings.executablePath.empty() || modelPath.empty()) {
		status =
			"Set OFXGGML_LLAMA_CLI and OFXGGML_TEXT_MODEL, then restart this example.";
		rebuildLines();
		return;
	}

	status = "running llama.cpp CLI...";
	rebuildLines();

	ofxGgmlTextRequest request;
	request.modelPath = modelPath;
	request.prompt = prompt;
	request.settings = settings;
	request.settings.maxTokens = 64;
	request.settings.temperature = 0.7f;
	request.settings.gpuLayers = -1;

	const auto result = generator.generate(
		request,
		[this](const std::string & chunk) {
			output += chunk;
			rebuildLines();
			return true;
		});

	if (result.success) {
		output = result.text;
		status = "complete via " + result.backendName;
	} else {
		status = "text error: " + result.error;
	}
	rebuildLines();
}

void ofApp::rebuildLines() {
	lines.clear();
	lines.push_back("ofxGgml text example");
	lines.push_back(status);
	lines.push_back("executable: " + (settings.executablePath.empty() ? "(unset)" : settings.executablePath));
	lines.push_back("model: " + (modelPath.empty() ? "(unset)" : modelPath));
	lines.push_back("");
	lines.push_back("prompt:");
	for (const auto & line : wrapText(prompt, 96)) {
		lines.push_back("  " + line);
	}
	lines.push_back("");
	lines.push_back("output:");
	if (output.empty()) {
		lines.push_back("  (none)");
	} else {
		for (const auto & line : wrapText(output, 96)) {
			lines.push_back("  " + line);
		}
	}
}

std::string ofApp::envValue(const char * name) {
	const char * value = std::getenv(name);
	return value ? std::string(value) : std::string();
}
