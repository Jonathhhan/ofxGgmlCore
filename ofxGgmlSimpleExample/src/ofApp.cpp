#include "ofApp.h"

#include <array>
#include <algorithm>
#include <cstdint>
#include <limits>
#include <utility>
#include <sstream>
#include <vector>

namespace {

const std::array<std::pair<ofxGgmlBackend, const char *>, 6> kBackends = {{
	{ofxGgmlBackend::Auto, "Auto"},
	{ofxGgmlBackend::CPU, "CPU"},
	{ofxGgmlBackend::CUDA, "CUDA"},
	{ofxGgmlBackend::Vulkan, "Vulkan"},
	{ofxGgmlBackend::Metal, "Metal"},
	{ofxGgmlBackend::OpenCL, "OpenCL"}
}};

const char * backendLabel(ofxGgmlBackend backend) {
	return ofxGgmlGetBackendName(backend);
}

std::string formatBytes(std::size_t bytes) {
	if (bytes == 0) {
		return "";
	}
	const double gib = static_cast<double>(bytes) / (1024.0 * 1024.0 * 1024.0);
	std::ostringstream stream;
	stream.setf(std::ios::fixed);
	stream.precision(1);
	stream << " (" << gib << " GiB)";
	return stream.str();
}

std::string formatDurationMs(float ms) {
	std::ostringstream stream;
	stream.setf(std::ios::fixed);
	stream.precision(3);
	stream << ms << " ms";
	return stream.str();
}

std::string formatThroughput(std::size_t elements, float msPerRun) {
	if (msPerRun <= 0.0f) {
		return "inf GB/s";
	}

	const double seconds = static_cast<double>(msPerRun) * 0.001;
	const double bytes = static_cast<double>(elements) * sizeof(float) * 3.0; // two inputs + one output
	const double gb = bytes / (1024.0 * 1024.0 * 1024.0);
	const double gbPerS = seconds > 0.0 ? gb / seconds : 0.0;

	std::ostringstream stream;
	stream.setf(std::ios::fixed);
	stream.precision(3);
	stream << gbPerS << " GB/s";
	return stream.str();
}

} // namespace

void ofApp::configureRuntime(ofxGgmlBackend backend) {
	ofxGgmlRuntimeSettings settings;
	settings.preferredBackend = backend;
	settings.allowCpuFallback = allowCpuFallback;
	ofLogNotice("ofxGgmlSimpleExample")
		<< "Configuring runtime | preferred backend: " << backendLabel(backend)
		<< " | cpu fallback: " << (allowCpuFallback ? "enabled" : "disabled");

	lines.clear();
	auto result = runtime.setup(settings);
	lines.push_back("ofxGgmlCore simple example");
	if (result) {
		lines.push_back("runtime ready: " + runtime.getBackendName());
	} else {
		lines.push_back("runtime error: " + result.error().message);
	}
	lines.push_back("preferred backend: " + std::string(backendLabel(backend)));
	lines.push_back("devices:");
	for (const auto & device : runtime.getDevices()) {
		lines.push_back(std::string("  ") + backendLabel(device.backend) + ": " + device.name + formatBytes(device.memoryBytes));
	}
	lines.push_back(std::string("cpu fallback: ") + (allowCpuFallback ? "enabled" : "disabled"));
	if (runtime.isReady()) {
		ofLogNotice("ofxGgmlSimpleExample")
			<< "Runtime ready on backend: " << runtime.getBackendName()
			<< " | device count: " << runtime.getDevices().size();
		lines.push_back("press Run to execute the compute graph");
		runtimeReady = true;
	} else {
		ofLogError("ofxGgmlSimpleExample")
			<< "Runtime init failed: " << result.error().message;
		lines.push_back("runtime not ready - adjust backend and rerun.");
		runtimeReady = false;
	}
	lastComputeTime = "--";
	lastThroughput = "--";
}

void ofApp::runComputation() {
	runBenchmark(std::max(1, elementCount), std::max(1, iterationCount));
}

void ofApp::runBenchmark(std::size_t elementCount, int iterationCount) {
	lines.push_back("");
	ofLogNotice("ofxGgmlSimpleExample")
		<< "Running benchmark | preferred backend: " << runtime.getBackendName()
		<< " | elements: " << elementCount
		<< " | iterations: " << iterationCount
		<< " | cpu fallback: " << (allowCpuFallback ? "enabled" : "disabled");
	lines.push_back("running benchmark");
	if (!runtime.isReady()) {
		ofLogError("ofxGgmlSimpleExample") << "Run skipped: runtime not ready";
		lines.push_back("run skipped: runtime not ready");
		return;
	}

	const std::uint64_t elementCount64 = static_cast<std::uint64_t>(elementCount);
	const std::uint64_t byteCount64 = elementCount64 * static_cast<std::uint64_t>(sizeof(float));
	const std::size_t byteCount = static_cast<std::size_t>(byteCount64);
	if (byteCount64 != static_cast<std::uint64_t>(byteCount)) {
		ofLogError("ofxGgmlSimpleExample") << "Invalid workload size: overflow";
		lines.push_back("invalid workload size (overflow)");
		return;
	}

	std::vector<float> left(static_cast<std::size_t>(elementCount), 1.0f);
	std::vector<float> right(static_cast<std::size_t>(elementCount), 2.0f);
	for (std::size_t index = 0; index < left.size(); ++index) {
		left[index] = 0.0001f * static_cast<float>(index % 1024);
		right[index] = 0.0002f * static_cast<float>((index * 2) % 1024);
	}

	graph = ofxGgmlGraph();
	ofxGgmlTensor a = graph.tensor1d(ofxGgmlType::F32, elementCount);
	ofxGgmlTensor b = graph.tensor1d(ofxGgmlType::F32, elementCount);
	ofxGgmlTensor sum = graph.add(a, b);
	graph.build(sum);

	auto allocateResult = runtime.allocate(graph);
	if (!allocateResult) {
		ofLogError("ofxGgmlSimpleExample")
			<< "Allocate failed (" << runtime.getBackendName() << "): " << allocateResult.error().message;
		lines.push_back("allocate error: " + allocateResult.error().message);
		return;
	}

	float totalMs = 0.0f;
	float minMs = std::numeric_limits<float>::infinity();
	float maxMs = 0.0f;
	for (int i = 0; i < iterationCount; ++i) {
		auto setLeft = runtime.setData(a, left.data(), byteCount);
		if (!setLeft) {
			ofLogError("ofxGgmlSimpleExample")
				<< "setData(left) failed: " << setLeft.error().message;
			lines.push_back("setData(left) error: " + setLeft.error().message);
			return;
		}
		auto setRight = runtime.setData(b, right.data(), byteCount);
		if (!setRight) {
			ofLogError("ofxGgmlSimpleExample")
				<< "setData(right) failed: " << setRight.error().message;
			lines.push_back("setData(right) error: " + setRight.error().message);
			return;
		}
		ofxGgmlComputeResult compute = runtime.compute(graph);
		if (!compute) {
			ofLogError("ofxGgmlSimpleExample")
				<< "Compute failed: " << (compute.error.empty() ? "graph compute failed" : compute.error);
			lines.push_back("compute error: " + (compute.error.empty() ? "graph compute failed" : compute.error));
			return;
		}
		totalMs += compute.elapsedMs;
		minMs = std::min(minMs, compute.elapsedMs);
		maxMs = std::max(maxMs, compute.elapsedMs);
	}

	std::vector<float> output(static_cast<std::size_t>(elementCount), 0.0f);
	auto readResult = runtime.getData(sum, output.data(), byteCount);
	if (!readResult) {
		ofLogError("ofxGgmlSimpleExample")
			<< "Readback failed: " << readResult.error().message;
		lines.push_back("read error: " + readResult.error().message);
		return;
	}

	const int maxPreview = 4;
	const float observedA = output.empty() ? 0.0f : output[0];
	const float observedB = output.size() > 1 ? output[1] : 0.0f;
	const float observedC = output.size() > 2 ? output[2] : 0.0f;
	const float observedD = output.size() > 3 ? output[3] : 0.0f;

	const float avgMs = totalMs / static_cast<float>(iterationCount);
	lastComputeTime = formatDurationMs(avgMs);
	lastThroughput = formatThroughput(elementCount, avgMs);
	ofLogNotice("ofxGgmlSimpleExample")
		<< "Benchmark done | backend: " << runtime.getBackendName()
		<< " | avg: " << lastComputeTime
		<< " | min/max: " << formatDurationMs(minMs)
		<< "/" << formatDurationMs(maxMs)
		<< " | throughput: " << lastThroughput
		<< " | elements: " << elementCount;
	lines.push_back("backend: " + runtime.getBackendName());
	lines.push_back("elements: " + std::to_string(elementCount) + ", iterations: " + std::to_string(iterationCount));
	lines.push_back("compute avg/min/max: " + formatDurationMs(avgMs) + " / " + formatDurationMs(minMs) + " / " + formatDurationMs(maxMs));
	lines.push_back("throughput (approx): " + lastThroughput);
	lines.push_back("first values: [" + std::to_string(observedA) + ", " + std::to_string(observedB) + ", " + std::to_string(observedC) + ", " + std::to_string(observedD) + "]");
	lines.push_back("preview count: " + std::to_string(maxPreview));
	lines.push_back("done");
}

void ofApp::setup() {
	ofSetWindowTitle("ofxGgmlCore Simple Example");
	ofBackground(12);
	gui.setup(nullptr, false);
	configureRuntime(ofxGgmlBackend::Auto);
	selectedBackendIndex = 0;
	lastComputeTime = "--";
}

void ofApp::draw() {
	ofBackground(12);

	gui.begin();
	ImGui::SetNextWindowPos(ImVec2(24.0f, 24.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(ImVec2(760.0f, 420.0f), ImGuiCond_Once);
	if (ImGui::Begin("ofxGgml Simple Example")) {
		ImGui::TextUnformatted("Runtime");
		ImGui::Text("backend:");
		if (ImGui::BeginCombo("##backend", backendLabel(kBackends[selectedBackendIndex].first))) {
			for (std::size_t index = 0; index < kBackends.size(); ++index) {
				const auto & backend = kBackends[index];
				const bool selected = static_cast<int>(index) == selectedBackendIndex;
				if (ImGui::Selectable(backend.second, selected)) {
					selectedBackendIndex = static_cast<int>(index);
					configureRuntime(backend.first);
				}
				if (selected) {
					ImGui::SetItemDefaultFocus();
				}
			}
			ImGui::EndCombo();
		}
		ImGui::SameLine();
		if (ImGui::Checkbox("CPU fallback", &allowCpuFallback)) {
			configureRuntime(kBackends[selectedBackendIndex].first);
		}
		ImGui::Text("elements");
		ImGui::SameLine();
		ImGui::InputInt("##elements", &elementCount, 1024, 1024 * 1024);
		ImGui::SameLine();
		ImGui::Text("iterations");
		ImGui::SameLine();
		ImGui::InputInt("##iters", &iterationCount, 1, 1);
		ImGui::SameLine();
		ImGui::Text("size: %s", (std::to_string(std::max(1, elementCount)) + " floats").c_str());

		if (!runtimeReady) {
			ImGui::BeginDisabled();
		}
		if (ImGui::Button("Run")) {
			runComputation();
		}
		if (!runtimeReady) {
			ImGui::EndDisabled();
		}
		ImGui::SameLine();
		ImGui::Text("avg calc time: %s", lastComputeTime.c_str());
		ImGui::SameLine();
		ImGui::Text("throughput: %s", lastThroughput.c_str());
		ImGui::Separator();
		for (const auto & line : lines) {
			if (line.rfind("runtime error:", 0) == 0 || line.rfind("compute error:", 0) == 0) {
				ImGui::TextColored(ImVec4(1.0f, 0.35f, 0.25f, 1.0f), "%s", line.c_str());
			} else {
				ImGui::TextWrapped("%s", line.c_str());
			}
		}
	}
	ImGui::End();
	gui.end();
	gui.draw();
}
