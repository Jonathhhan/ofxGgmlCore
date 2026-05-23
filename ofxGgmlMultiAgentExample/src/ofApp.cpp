#include "ofApp.h"
#include <algorithm>
#include <array>
#include <chrono>
#include <sstream>
#include <thread>

namespace {

constexpr const char * LogModule = "ofxGgmlMultiAgentExample";

std::string formatMs(double ms) {
	std::ostringstream stream;
	stream.setf(std::ios::fixed);
	stream.precision(ms < 10.0 ? 3 : 1);
	stream << ms << " ms";
	return stream.str();
}

void appendLine(std::vector<std::string> & lines, const std::string & line, bool isError = false) {
	lines.push_back(line);
	if (isError) {
		ofLogWarning(LogModule) << line;
	} else {
		ofLogNotice(LogModule) << line;
	}
}

unsigned int getInteractiveThreadBudget() {
	const unsigned int hardwareThreads = std::max(1u, std::thread::hardware_concurrency());
	if (hardwareThreads <= 2u) {
		return 1u;
	}
	return hardwareThreads - 2u;
}

} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml Multi-Agent Thread Configuration Example");
	ofBackground(12);
	gui.setup(nullptr, false);

	lines.clear();
	appendLine(lines, "Multi-Agent Thread Configuration Demo");
	appendLine(lines, "=======================================");
	appendLine(lines, "");
	appendLine(lines, "This example demonstrates how to configure");
	appendLine(lines, "different thread configurations for multiple agents");
	appendLine(lines, "using the PerAgent thread mode.");
	appendLine(lines, "");
	appendLine(lines, "Instructions:");
	appendLine(lines, "1. Select 'PerAgent' thread mode");
	appendLine(lines, "2. Click 'Configure Agents'");
	appendLine(lines, "3. Reserve two hardware threads for UI/rendering");
	appendLine(lines, "4. Click 'Run' to see thread pool behavior");
}

void ofApp::configureAgents() {
	lines.clear();
	appendLine(lines, "Agent Configuration");
	appendLine(lines, "-------------------");

	const std::array<std::string, 3> agentIds {
		"planner",
		"executor",
		"refiner"
	};
	const unsigned int hardwareThreads = std::max(1u, std::thread::hardware_concurrency());
	const unsigned int interactiveBudget = getInteractiveThreadBudget();
	const int agentCount = static_cast<int>(agentIds.size());
	const int threadsPerAgent = std::max(1, static_cast<int>(interactiveBudget) / agentCount);

	runtime.setThreadMode(ofxGgmlThreadMode::PerAgent);
	runtime.clearAgentThreadConfigs();

	appendLine(lines, "Hardware threads: " + std::to_string(hardwareThreads));
	appendLine(lines, "Interactive budget: " + std::to_string(interactiveBudget) + " threads");
	appendLine(lines, "Reserved for openFrameworks/UI: " +
		std::to_string(hardwareThreads - interactiveBudget) + " threads");
	appendLine(lines, "Max concurrent agents: " + std::to_string(agentCount));
	appendLine(lines, "Threads per agent: " + std::to_string(threadsPerAgent));
	appendLine(lines, "");

	for (const auto & agentId : agentIds) {
		runtime.setAgentThreadConfig(agentId, { threadsPerAgent, false });
		appendLine(lines, "Agent '" + agentId + "': " +
			std::to_string(threadsPerAgent) + " threads");
	}

	appendLine(lines, "");
	appendLine(lines, "Shared mode alternative: all agents share " +
		std::to_string(interactiveBudget) + " threads");
}

void ofApp::runBenchmark() {
	lines.clear();
	appendLine(lines, "Benchmark Results");
	appendLine(lines, "-----------------");

	const int elementCount = 65536;
	const int iterationCount = 10;

	// Setup runtime
	ofxGgmlRuntimeSettings settings;
	settings.preferredBackend = ofxGgmlBackend::Auto;
	settings.allowCpuFallback = true;
	settings.threadMode = runtime.getThreadMode();
	settings.agentThreads = runtime.getAllAgentThreadConfigs();

	auto result = runtime.setup(settings);
	if (!result) {
		appendLine(lines, "Runtime setup failed: " + result.error().message, true);
		return;
	}

	appendLine(lines, "Runtime ready: " + runtime.getBackendName());

	// Create a simple computation graph
	graph = ofxGgmlGraph(128u * 1024u * 1024u);
	ofxGgmlTensor a = graph.tensor1d(ofxGgmlType::F32, elementCount);
	ofxGgmlTensor b = graph.tensor1d(ofxGgmlType::F32, elementCount);
	ofxGgmlTensor resultTensor = graph.add(a, b);
	graph.build({ a, b, resultTensor });

	std::vector<float> left(elementCount);
	std::vector<float> right(elementCount);
	for (std::size_t i = 0; i < elementCount; ++i) {
		left[i] = static_cast<float>(i);
		right[i] = static_cast<float>(i) * 0.5f;
	}

	// Allocate and set data
	auto allocateResult = runtime.allocate(graph);
	if (!allocateResult) {
		appendLine(lines, "Graph allocation failed: " + allocateResult.error().message, true);
		return;
	}

	auto setDataResult = runtime.setData(a, left.data(), left.size() * sizeof(float));
	if (!setDataResult) {
		appendLine(lines, "Failed to set input data: " + setDataResult.error().message, true);
		return;
	}

	setDataResult = runtime.setData(b, right.data(), right.size() * sizeof(float));
	if (!setDataResult) {
		appendLine(lines, "Failed to set input data: " + setDataResult.error().message, true);
		return;
	}

	// Run benchmark
	double totalMs = 0.0;
	for (int i = 0; i < iterationCount; ++i) {
		ofxGgmlComputeResult compute = runtime.compute(graph);
		if (!compute) {
			appendLine(lines, "Compute failed: " + compute.error, true);
			return;
		}
		totalMs += compute.elapsedMs;
	}

	const double averageMs = totalMs / iterationCount;
	appendLine(lines, "Thread mode: " + std::string(runtime.getThreadMode() == ofxGgmlThreadMode::PerAgent ? "PerAgent" : "Shared"));
	appendLine(lines, "Benchmark: " + std::to_string(elementCount) + " F32 elements x 3 ops x " + std::to_string(iterationCount) + " iterations");
	appendLine(lines, "Total time: " + formatMs(totalMs));
	appendLine(lines, "Average time: " + formatMs(averageMs));
}

void ofApp::draw() {
	ofBackground(12);

	gui.begin();
	ImGui::SetNextWindowPos(ImVec2(24.0f, 24.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(ImVec2(760.0f, 400.0f), ImGuiCond_Once);
	if (ImGui::Begin("ofxGgml Multi-Agent Example")) {
		ImGui::TextUnformatted("Thread Configuration");
		ImGui::Separator();

		ImGui::Text("Thread Mode:");
		ImGui::SameLine();
		const char * modeLabel = runtime.getThreadMode() == ofxGgmlThreadMode::PerAgent ? "PerAgent" : "Shared";
		ImGui::TextColored(ImVec4(0.0f, 1.0f, 1.0f, 1.0f), "%s", modeLabel);
		ImGui::SameLine();
		ImGui::Text("(PerAgent allows different thread counts per agent)");

		ImGui::Separator();
		ImGui::Text("Agent Configurations:");
		const auto agentThreadConfigs = runtime.getAllAgentThreadConfigs();
		if (agentThreadConfigs.empty()) {
			ImGui::TextColored(ImVec4(0.8f, 0.8f, 0.8f, 1.0f), "No per-agent configs set");
		} else {
			for (const auto & agentConfig : agentThreadConfigs) {
				ImGui::TextColored(ImVec4(1.0f, 1.0f, 0.0f, 1.0f),
					"Agent '%s': %d threads",
					agentConfig.first.c_str(),
					agentConfig.second.threads);
			}
		}

		ImGui::Separator();
		ImGui::Spacing();
		if (ImGui::Button("Configure Agents", ImVec2(160.0f, 0.0f))) {
			configureAgents();
		}
		ImGui::SameLine();
		if (ImGui::Button("Run Benchmark", ImVec2(160.0f, 0.0f))) {
			runBenchmark();
		}

		ImGui::Separator();
		ImGui::TextUnformatted("Log Output:");
		ImGui::BeginChild("Log", ImVec2(0, 0), true);
		for (const auto & line : lines) {
			ImGui::TextWrapped("%s", line.c_str());
		}
		ImGui::EndChild();
	}
	ImGui::End();
	gui.end();
	gui.draw();
}
