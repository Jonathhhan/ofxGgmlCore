#include "ofApp.h"

#include "imgui_stdlib.h"

#include <algorithm>
#include <cctype>
#include <cstdlib>
#include <iomanip>
#include <iostream>
#include <memory>
#include <sstream>
#include <utility>

namespace {

std::string trimText(const std::string & text) {
	std::size_t first = 0;
	while (first < text.size() &&
		std::isspace(static_cast<unsigned char>(text[first]))) {
		++first;
	}
	std::size_t last = text.size();
	while (last > first &&
		std::isspace(static_cast<unsigned char>(text[last - 1]))) {
		--last;
	}
	return text.substr(first, last - first);
}

ImVec2 fitWindowSize(float preferredWidth, float preferredHeight) {
	const ImVec2 display = ImGui::GetIO().DisplaySize;
	const float availableWidth = std::max(420.0f, display.x - 32.0f);
	const float availableHeight = std::max(360.0f, display.y - 32.0f);
	return ImVec2(
		std::min(preferredWidth, availableWidth),
		std::min(preferredHeight, availableHeight));
}

} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml embedding example");
	ofBackground(12);
	gui.setup(nullptr, false);

	settings.serverUrl = normalizeEnvText(envValue("OFXGGML_EMBEDDING_SERVER_URL"));
	settings.serverModel = normalizeEnvText(envValue("OFXGGML_EMBEDDING_SERVER_MODEL"));
	if (settings.serverUrl.empty()) {
		settings.serverUrl = "http://127.0.0.1:8081";
	}
	configureGenerator();

	input = "openFrameworks local inference";
	inputEdit = input;
	inputEdit.reserve(4096);

	std::lock_guard<std::mutex> lock(stateMutex);
	status = "ready";
}

void ofApp::draw() {
	std::string statusSnapshot;
	std::string errorSnapshot;
	std::string serverUrlSnapshot;
	std::string serverModelSnapshot;
	std::vector<float> embeddingSnapshot;
	bool runningSnapshot = false;
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		statusSnapshot = status;
		errorSnapshot = error;
		serverUrlSnapshot = settings.serverUrl;
		serverModelSnapshot = settings.serverModel;
		embeddingSnapshot = embedding;
		runningSnapshot = running;
	}

	bool shouldRun = false;

	ofBackground(12);
	gui.begin();
	ImGui::SetNextWindowPos(ImVec2(16.0f, 16.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(fitWindowSize(900.0f, 480.0f), ImGuiCond_Once);
	if (ImGui::Begin("ofxGgml Embedding Example")) {
		if (runningSnapshot) {
			ImGui::BeginDisabled();
		}
		if (ImGui::Button("Run", ImVec2(72.0f, 0.0f))) {
			shouldRun = true;
		}
		if (runningSnapshot) {
			ImGui::EndDisabled();
		}

		ImGui::Separator();
		const ImVec4 statusColor = runningSnapshot
			? ImVec4(0.45f, 0.75f, 1.0f, 1.0f)
			: ImVec4(0.70f, 0.92f, 0.70f, 1.0f);
		ImGui::TextColored(statusColor, "%s", statusSnapshot.c_str());
		ImGui::Text("State: %s", runningSnapshot ? "running" : "idle");
		ImGui::Text("Backend: llama-server embeddings");

		if (ImGui::CollapsingHeader("Runtime", ImGuiTreeNodeFlags_DefaultOpen)) {
			std::string serverUrlEdit = serverUrlSnapshot;
			std::string serverModelEdit = serverModelSnapshot;
			if (runningSnapshot) {
				ImGui::BeginDisabled();
			}
			ImGui::SetNextItemWidth(-1.0f);
			if (ImGui::InputText("Server URL", &serverUrlEdit)) {
				std::lock_guard<std::mutex> lock(stateMutex);
				settings.serverUrl = normalizeEnvText(serverUrlEdit);
				configureGenerator();
			}
			ImGui::SetNextItemWidth(-1.0f);
			if (ImGui::InputText("Server model", &serverModelEdit)) {
				std::lock_guard<std::mutex> lock(stateMutex);
				settings.serverModel = normalizeEnvText(serverModelEdit);
			}
			if (runningSnapshot) {
				ImGui::EndDisabled();
			}
			ImGui::TextWrapped(
				"Use scripts/start-llama-server.bat -Embeddings to run a dedicated embedding server.");
		}

		ImGui::Spacing();
		ImGui::TextUnformatted("Input");
		ImGui::Separator();
		ImGui::InputTextMultiline(
			"##embedding-input",
			&inputEdit,
			ImVec2(0.0f, 86.0f),
			runningSnapshot ? ImGuiInputTextFlags_ReadOnly : ImGuiInputTextFlags_None);

		ImGui::Spacing();
		ImGui::TextUnformatted("Embedding");
		ImGui::Separator();
		ImGui::BeginChild("ofxGgmlEmbeddingOutput", ImVec2(0.0f, 150.0f), true);
		if (!errorSnapshot.empty()) {
			ImGui::TextWrapped("Error: %s", errorSnapshot.c_str());
		} else if (embeddingSnapshot.empty()) {
			ImGui::TextDisabled("(none)");
		} else {
			ImGui::Text("Dimension: %d", static_cast<int>(embeddingSnapshot.size()));
			const std::string preview = embeddingPreview(embeddingSnapshot);
			ImGui::TextWrapped("%s", preview.c_str());
		}
		ImGui::EndChild();
	}
	ImGui::End();
	gui.end();
	gui.draw();

	if (shouldRun) {
		startEmbedding();
	}
}

void ofApp::keyPressed(int key) {
	if (ImGui::GetCurrentContext() && ImGui::GetIO().WantCaptureKeyboard) {
		return;
	}
	if (key == 'r' || key == 'R') {
		startEmbedding();
	}
}

void ofApp::exit() {
	if (worker.joinable()) {
		worker.join();
	}
}

void ofApp::startEmbedding() {
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		if (running) {
			status = "embedding request is already running";
			return;
		}
	}

	if (worker.joinable()) {
		worker.join();
	}

	{
		std::lock_guard<std::mutex> lock(stateMutex);
		input = trimText(inputEdit);
		if (input.empty()) {
			status = "type input text first";
			error.clear();
			embedding.clear();
			return;
		}
		status = "requesting embedding...";
		error.clear();
		embedding.clear();
		running = true;
	}

	worker = std::thread(&ofApp::runEmbeddingWorker, this);
}

void ofApp::runEmbeddingWorker() {
	ofxGgmlEmbeddingSettings requestSettings;
	std::string requestInput;
	{
		std::lock_guard<std::mutex> lock(stateMutex);
		requestSettings = settings;
		requestInput = input;
	}

	if (requestSettings.serverUrl.empty()) {
		std::lock_guard<std::mutex> lock(stateMutex);
		status = "embedding error";
		error = "No embedding server URL configured.";
		running = false;
		return;
	}

	ofxGgmlEmbeddingRequest request;
	request.input = requestInput;
	request.settings = requestSettings;

	std::cout << "\n[ofxGgmlEmbeddingExample] input\n"
		<< request.input
		<< "\n" << std::flush;

	const auto result = generator.embed(request);

	std::cout << "\n[ofxGgmlEmbeddingExample] output\n";
	if (result.success) {
		std::cout << "dimension: " << result.embedding.size() << "\n"
			<< embeddingPreview(result.embedding) << "\n";
	} else {
		std::cout << "ERROR: " << result.error << "\n";
	}
	std::cout << std::flush;

	std::lock_guard<std::mutex> lock(stateMutex);
	if (result.success) {
		embedding = result.embedding;
		error.clear();
		status = "complete via " + result.backendName + " in " +
			std::to_string(static_cast<int>(result.elapsedMs)) + " ms";
	} else {
		embedding.clear();
		error = result.error;
		status = "embedding error";
	}
	running = false;
}

void ofApp::configureGenerator() {
	generator.setBackend(
		std::make_shared<ofxGgmlLlamaServerEmbeddingBackend>(settings.serverUrl));
}

std::string ofApp::normalizeEnvText(const std::string & text) {
	std::string normalized = trimText(text);
	if (normalized.size() >= 2 && normalized.front() == '"' && normalized.back() == '"') {
		normalized = normalized.substr(1, normalized.size() - 2);
	}
	return normalized;
}

std::string ofApp::embeddingPreview(const std::vector<float> & values) {
	std::ostringstream preview;
	preview << std::fixed << std::setprecision(5);
	const std::size_t count = std::min<std::size_t>(values.size(), 32);
	for (std::size_t i = 0; i < count; ++i) {
		if (i > 0) {
			preview << ", ";
		}
		preview << values[i];
	}
	if (values.size() > count) {
		preview << ", ...";
	}
	return preview.str();
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
