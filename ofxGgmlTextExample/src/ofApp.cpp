#include "ofApp.h"

#include <cstdlib>
#include <cctype>
#include <filesystem>
#include <memory>
#include <sstream>
#include <utility>

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#elif defined(__APPLE__)
#include <mach-o/dyld.h>
#else
#include <unistd.h>
#endif

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

std::string toString(const std::filesystem::path & path) {
	return path.lexically_normal().string();
}

bool pathExists(const std::filesystem::path & path) {
	std::error_code error;
	return std::filesystem::is_regular_file(path, error);
}

std::filesystem::path executableDirectory() {
#if defined(_WIN32)
	std::wstring buffer(MAX_PATH, L'\0');
	DWORD length = GetModuleFileNameW(
		nullptr,
		buffer.data(),
		static_cast<DWORD>(buffer.size()));
	while (length == buffer.size()) {
		buffer.resize(buffer.size() * 2);
		length = GetModuleFileNameW(
			nullptr,
			buffer.data(),
			static_cast<DWORD>(buffer.size()));
	}
	if (length > 0) {
		buffer.resize(length);
		return std::filesystem::path(buffer).parent_path();
	}
#elif defined(__APPLE__)
	uint32_t size = 0;
	_NSGetExecutablePath(nullptr, &size);
	std::string buffer(size, '\0');
	if (_NSGetExecutablePath(buffer.data(), &size) == 0) {
		return std::filesystem::path(buffer.c_str()).parent_path();
	}
#else
	std::string buffer(4096, '\0');
	const ssize_t length = readlink("/proc/self/exe", buffer.data(), buffer.size() - 1);
	if (length > 0) {
		buffer.resize(static_cast<std::size_t>(length));
		return std::filesystem::path(buffer).parent_path();
	}
#endif
	std::error_code error;
	return std::filesystem::current_path(error);
}

void addUniquePath(
	std::vector<std::filesystem::path> & paths,
	const std::filesystem::path & path) {
	if (path.empty()) {
		return;
	}
	const std::filesystem::path normalized = path.lexically_normal();
	for (const auto & existing : paths) {
		if (existing == normalized) {
			return;
		}
	}
	paths.push_back(normalized);
}

std::vector<std::filesystem::path> searchRoots() {
	std::vector<std::filesystem::path> roots;
	std::error_code error;
	addUniquePath(roots, executableDirectory());
	addUniquePath(roots, std::filesystem::current_path(error));

	const std::size_t initialCount = roots.size();
	for (std::size_t i = 0; i < initialCount; ++i) {
		std::filesystem::path parent = roots[i];
		for (int depth = 0; depth < 5 && !parent.empty(); ++depth) {
			addUniquePath(roots, parent);
			parent = parent.parent_path();
		}
	}
	return roots;
}

std::string findFirstFile(const std::vector<std::filesystem::path> & candidates) {
	for (const auto & candidate : candidates) {
		if (pathExists(candidate)) {
			return toString(candidate);
		}
	}
	return {};
}

std::string findFirstFileByExtension(
	const std::vector<std::filesystem::path> & roots,
	const std::vector<std::filesystem::path> & relativeDirectories,
	const std::string & extension) {
	for (const auto & root : roots) {
		for (const auto & relative : relativeDirectories) {
			const std::filesystem::path directory = (root / relative).lexically_normal();
			std::error_code error;
			if (!std::filesystem::is_directory(directory, error)) {
				continue;
			}
			for (const auto & entry : std::filesystem::directory_iterator(directory, error)) {
				if (error) {
					break;
				}
				if (entry.is_regular_file(error) && entry.path().extension() == extension) {
					return toString(entry.path());
				}
			}
		}
	}
	return {};
}

std::string discoverLlamaCli() {
#if defined(_WIN32)
	const std::vector<std::string> executableNames = {
		"llama-cli.exe",
		"main.exe",
		"llama.exe"
	};
#else
	const std::vector<std::string> executableNames = {
		"llama-cli",
		"main",
		"llama"
	};
#endif
	const std::vector<std::filesystem::path> relativeDirectories = {
		"",
		"bin",
		"data",
		"data/bin",
		"tools",
		"models",
		"libs/llama.cpp/build/bin",
		"libs/llama.cpp/build/bin/Release",
		"libs/llama.cpp/build/bin/Debug"
	};

	std::vector<std::filesystem::path> candidates;
	for (const auto & root : searchRoots()) {
		for (const auto & relative : relativeDirectories) {
			for (const auto & name : executableNames) {
				candidates.push_back(root / relative / name);
			}
		}
	}
	return findFirstFile(candidates);
}

std::string discoverTextModel() {
	return findFirstFileByExtension(
		searchRoots(),
		{
			"",
			"data",
			"data/models",
			"models",
			"ofxGgmlTextExample/bin/data",
			"ofxGgmlTextExample/bin/data/models",
			"ofxGgmlTextExample/models"
		},
		".gguf");
}

} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml text example");
	ofBackground(12);

	settings.executablePath = normalizeEnvPath(envValue("OFXGGML_LLAMA_CLI"));
	modelPath = normalizeEnvPath(envValue("OFXGGML_TEXT_MODEL"));
	autoConfigureTextBackend(settings, modelPath);
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
		fail("No llama.cpp CLI found. Set OFXGGML_LLAMA_CLI or place llama-cli beside the app.");
		return;
	}
	if (!fileExists(requestSettings.executablePath)) {
		fail("OFXGGML_LLAMA_CLI was not found: " + requestSettings.executablePath);
		return;
	}
	if (requestModelPath.empty()) {
		fail("No GGUF model found. Set OFXGGML_TEXT_MODEL or place one under bin/data/models.");
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
	lines.push_back("env is optional if llama-cli and a .gguf model are in local search paths");
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

void ofApp::autoConfigureTextBackend(
	ofxGgmlTextGenerationSettings & settings,
	std::string & modelPath) {
	if (settings.executablePath.empty()) {
		settings.executablePath = discoverLlamaCli();
	}
	if (modelPath.empty()) {
		modelPath = discoverTextModel();
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
