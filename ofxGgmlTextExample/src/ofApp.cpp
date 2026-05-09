#include "ofApp.h"

#include <cstdlib>
#include <cctype>
#include <memory>
#include <sstream>
#include <utility>

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

	settings.executablePath = normalizeEnvPath(envValue("OFXGGML_LLAMA_CLI"));
	modelPath = normalizeEnvPath(envValue("OFXGGML_TEXT_MODEL"));
	prompt = "Write one concise sentence about local inference in openFrameworks.";

	generator.setBackend(std::make_shared<ofxGgmlLlamaCliTextBackend>());
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		status = "starting text request...";
		rebuildLinesLocked();
	}
	startPrompt();
}

void ofApp::draw() {
	std::vector<std::string> snapshot;
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		snapshot = lines;
	}

	ofSetColor(240);
	int y = 36;
	for (const auto & line : snapshot) {
		ofDrawBitmapString(line, 32, y);
		y += 22;
	}
}

void ofApp::keyPressed(int key) {
	if (key == 'r' || key == 'R') {
		startPrompt();
		return;
	}
	if (key == 'c' || key == 'C') {
		cancelRequested = true;
		std::lock_guard<std::mutex> lock(stateMutex);
		if (running) {
			status = "cancelling after the next llama.cpp output chunk...";
			rebuildLinesLocked();
		}
	}
}

void ofApp::exit() {
	cancelRequested = true;
	if (worker.joinable()) {
		worker.join();
	}
}

void ofApp::startPrompt() {
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		if (running) {
			status = "text request is already running";
			rebuildLinesLocked();
			return;
		}
	}

	if (worker.joinable()) {
		worker.join();
	}

	{
		std::lock_guard<std::mutex> lock(stateMutex);
		output.clear();
		status = "checking text backend configuration...";
		running = true;
		cancelRequested = false;
		rebuildLinesLocked();
	}

	worker = std::thread(&ofApp::runPromptWorker, this);
}

void ofApp::runPromptWorker() {
	auto fail = [this](std::string message) {
		std::lock_guard<std::mutex> lock(stateMutex);
		status = std::move(message);
		running = false;
		rebuildLinesLocked();
	};

	ofxGgmlTextGenerationSettings requestSettings;
	std::string requestModelPath;
	std::string requestPrompt;
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		requestSettings = settings;
		requestModelPath = modelPath;
		requestPrompt = prompt;
	}

	if (requestSettings.executablePath.empty()) {
		fail("Set OFXGGML_LLAMA_CLI to a llama.cpp CLI executable, then press R.");
		return;
	}
	if (!fileExists(requestSettings.executablePath)) {
		fail("OFXGGML_LLAMA_CLI was not found: " + requestSettings.executablePath);
		return;
	}
	if (requestModelPath.empty()) {
		fail("Set OFXGGML_TEXT_MODEL to a GGUF model file, then press R.");
		return;
	}
	if (!fileExists(requestModelPath)) {
		fail("OFXGGML_TEXT_MODEL was not found: " + requestModelPath);
		return;
	}

	{
		std::lock_guard<std::mutex> lock(stateMutex);
		status = "running llama.cpp CLI...";
		rebuildLinesLocked();
	}

	ofxGgmlTextRequest request;
	request.modelPath = requestModelPath;
	request.prompt = requestPrompt;
	request.settings = requestSettings;
	request.settings.maxTokens = 64;
	request.settings.temperature = 0.7f;
	request.settings.gpuLayers = -1;

	const auto result = generator.generate(
		request,
		[this](const std::string & chunk) {
			if (cancelRequested) {
				return false;
			}
			std::lock_guard<std::mutex> lock(stateMutex);
			output += chunk;
			status = "receiving llama.cpp output...";
			rebuildLinesLocked();
			return !cancelRequested;
		});

	std::lock_guard<std::mutex> lock(stateMutex);
	if (result.success) {
		output = result.text;
		status = "complete via " + result.backendName + " in " +
			std::to_string(static_cast<int>(result.elapsedMs)) + " ms";
	} else {
		if (output.empty() && !result.rawOutput.empty()) {
			output = result.rawOutput;
		}
		status = "text error: " + result.error;
	}
	running = false;
	rebuildLinesLocked();
}

void ofApp::rebuildLinesLocked() {
	lines.clear();
	lines.push_back("ofxGgml text example");
	lines.push_back(status);
	lines.push_back(std::string("state: ") + (running ? "running" : "idle"));
	lines.push_back("keys: R run again, C cancel");
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

std::string ofApp::normalizeEnvPath(const std::string & path) {
	std::size_t first = 0;
	while (first < path.size() &&
		std::isspace(static_cast<unsigned char>(path[first]))) {
		++first;
	}
	std::size_t last = path.size();
	while (last > first &&
		std::isspace(static_cast<unsigned char>(path[last - 1]))) {
		--last;
	}
	std::string normalized = path.substr(first, last - first);
	if (normalized.size() >= 2 && normalized.front() == '"' && normalized.back() == '"') {
		normalized = normalized.substr(1, normalized.size() - 2);
	}
	return normalized;
}

bool ofApp::fileExists(const std::string & path) {
	return !path.empty() && ofFile::doesFileExist(path, false);
}

std::string ofApp::envValue(const char * name) {
#if defined(_WIN32)
	char * value = nullptr;
	std::size_t length = 0;
	if (_dupenv_s(&value, &length, name) != 0 || !value) {
		return {};
	}
	std::string result(value, length > 0 ? length - 1 : 0);
	free(value);
	return result;
#else
	const char * value = std::getenv(name);
	return value ? std::string(value) : std::string();
#endif
}
