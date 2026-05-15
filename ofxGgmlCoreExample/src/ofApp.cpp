#include "ofApp.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <sstream>

namespace {

constexpr const char * LogModule = "ofxGgmlCoreExample";

std::string backendLabel(ofxGgmlBackend backend) {
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

std::string formatMs(double ms) {
	std::ostringstream stream;
	stream.setf(std::ios::fixed);
	stream.precision(ms < 10.0 ? 3 : 1);
	stream << ms << " ms";
	return stream.str();
}

std::string formatSample(const std::vector<float> & values) {
	std::ostringstream stream;
	const std::size_t count = std::min<std::size_t>(values.size(), 4);
	for (std::size_t i = 0; i < count; ++i) {
		if (i > 0) {
			stream << ", ";
		}
		stream << values[i];
	}
	return stream.str();
}

float expectedValue(int index) {
	const float left = static_cast<float>((index % 97) + 1);
	const float right = static_cast<float>((index % 31) + 1) * 0.25f;
	const float sum = left + right;
	const float mixed = sum * right;
	const float boosted = mixed + left;
	const float scaled = boosted * sum;
	return scaled + mixed;
}

void appendLine(std::vector<std::string> & lines, const std::string & line, bool warning = false) {
	lines.push_back(line);
	if (warning) {
		ofLogWarning(LogModule) << line;
	} else {
		ofLogNotice(LogModule) << line;
	}
}

} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml Core Example");
	ofBackground(12);
	gui.setup(nullptr, false);

	backendOptions = {
		ofxGgmlBackend::Auto,
		ofxGgmlBackend::CPU,
		ofxGgmlBackend::CUDA,
		ofxGgmlBackend::Vulkan,
		ofxGgmlBackend::Metal,
		ofxGgmlBackend::OpenCL
	};
	lines.clear();
	appendLine(lines, "Select a backend and press Run.");
}

ofxGgmlBackend ofApp::getSelectedBackend() const {
	if (selectedBackendIndex < 0 || selectedBackendIndex >= static_cast<int>(backendOptions.size())) {
		return ofxGgmlBackend::Auto;
	}
	return backendOptions[static_cast<std::size_t>(selectedBackendIndex)];
}

void ofApp::runBackendCheck() {
	lastRunHadError = false;
	lastBackendName = "not run";
	lines.clear();

	const ofxGgmlBackend requestedBackend = getSelectedBackend();
	const int elementCount = std::max(workloadElements, 4);
	const int iterationCount = std::max(workloadIterations, 1);

	runtime.close();
	ofxGgmlRuntimeSettings settings;
	settings.preferredBackend = requestedBackend;
	settings.allowCpuFallback = allowCpuFallback;

	appendLine(lines, "requested backend: " + backendLabel(requestedBackend));
	appendLine(lines, std::string("CPU fallback: ") + (allowCpuFallback ? "enabled" : "disabled"));

	auto result = runtime.setup(settings);
	if (!result) {
		lastRunHadError = true;
		appendLine(lines, "runtime error: " + result.error().message, true);
		return;
	}

	lastBackendName = runtime.getBackendName();
	appendLine(lines, "runtime ready: " + lastBackendName);
	appendLine(lines, "devices:");
	for (const auto & device : runtime.getDevices()) {
		appendLine(lines, "  " + backendLabel(device.backend) + ": " + device.name + formatBytes(device.memoryBytes));
	}

	constexpr int graphOpCount = 5;
	graph = ofxGgmlGraph(64u * 1024u * 1024u);
	ofxGgmlTensor a = graph.tensor1d(ofxGgmlType::F32, elementCount);
	ofxGgmlTensor b = graph.tensor1d(ofxGgmlType::F32, elementCount);
	ofxGgmlTensor sum = graph.add(a, b);
	ofxGgmlTensor mixed = graph.mul(sum, b);
	ofxGgmlTensor boosted = graph.add(mixed, a);
	ofxGgmlTensor scaled = graph.mul(boosted, sum);
	ofxGgmlTensor resultTensor = graph.add(scaled, mixed);
	graph.build({ sum, mixed, boosted, scaled, resultTensor });

	std::vector<float> left(static_cast<std::size_t>(elementCount));
	std::vector<float> right(static_cast<std::size_t>(elementCount));
	std::vector<float> output(static_cast<std::size_t>(elementCount));
	for (int i = 0; i < elementCount; ++i) {
		left[static_cast<std::size_t>(i)] = static_cast<float>((i % 97) + 1);
		right[static_cast<std::size_t>(i)] = static_cast<float>((i % 31) + 1) * 0.25f;
	}

	std::string graphError;
	auto allocateResult = runtime.allocate(graph);
	if (!allocateResult) {
		graphError = allocateResult.error().message;
	}

	auto setLeft = graphError.empty() ? runtime.setData(a, left.data(), left.size() * sizeof(float)) : ofxGgmlResult<void>::failure(graphError);
	if (!setLeft && graphError.empty()) {
		graphError = setLeft.error().message;
	}
	auto setRight = graphError.empty() ? runtime.setData(b, right.data(), right.size() * sizeof(float)) : ofxGgmlResult<void>::failure(graphError);
	if (!setRight && graphError.empty()) {
		graphError = setRight.error().message;
	}

	double computeMs = 0.0;
	const auto wallStart = std::chrono::steady_clock::now();
	for (int i = 0; graphError.empty() && i < iterationCount; ++i) {
		ofxGgmlComputeResult compute = runtime.compute(graph);
		if (!compute) {
			graphError = compute.error.empty() ? "graph compute failed" : compute.error;
			break;
		}
		computeMs += compute.elapsedMs;
	}
	const auto wallEnd = std::chrono::steady_clock::now();
	const double wallMs = std::chrono::duration<double, std::milli>(wallEnd - wallStart).count();

	auto readResult = graphError.empty()
		? runtime.getData(resultTensor, output.data(), output.size() * sizeof(float))
		: ofxGgmlResult<void>::failure(graphError);

	if (!readResult) {
		lastRunHadError = true;
		appendLine(lines, "graph error: " + readResult.error().message, true);
		return;
	}

	float maxAbsError = 0.0f;
	for (int i = 0; i < elementCount; ++i) {
		const float expected = expectedValue(i);
		maxAbsError = std::max(maxAbsError, std::abs(output[static_cast<std::size_t>(i)] - expected));
	}

	const double averageComputeMs = iterationCount > 0 ? computeMs / static_cast<double>(iterationCount) : 0.0;
	const double elementOps = static_cast<double>(elementCount) * static_cast<double>(graphOpCount) * static_cast<double>(iterationCount);
	appendLine(lines, "workload: " + std::to_string(elementCount) + " F32 elements x " + std::to_string(graphOpCount) + " graph ops x " + std::to_string(iterationCount) + " iterations");
	appendLine(lines, "approx element ops: " + std::to_string(static_cast<long long>(elementOps)));
	appendLine(lines, "backend compute time: " + formatMs(computeMs) + " total, " + formatMs(averageComputeMs) + " average");
	appendLine(lines, "wall time: " + formatMs(wallMs));
	appendLine(lines, "correctness check: max abs error " + std::to_string(maxAbsError));
	appendLine(lines, "first output values: [" + formatSample(output) + "]");
}

void ofApp::draw() {
	ofBackground(12);

	gui.begin();
	ImGui::SetNextWindowPos(ImVec2(24.0f, 24.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(ImVec2(760.0f, 460.0f), ImGuiCond_Once);
	if (ImGui::Begin("ofxGgml Core Example")) {
		ImGui::TextUnformatted("Runtime");
		ImGui::Separator();

		const char * selectedLabel = ofxGgmlGetBackendName(getSelectedBackend());
		if (ImGui::BeginCombo("Backend", selectedLabel)) {
			for (int i = 0; i < static_cast<int>(backendOptions.size()); ++i) {
				const bool selected = (selectedBackendIndex == i);
				if (ImGui::Selectable(ofxGgmlGetBackendName(backendOptions[static_cast<std::size_t>(i)]), selected)) {
					selectedBackendIndex = i;
				}
				if (selected) {
					ImGui::SetItemDefaultFocus();
				}
			}
			ImGui::EndCombo();
		}
		ImGui::Checkbox("Allow CPU fallback", &allowCpuFallback);
		ImGui::SliderInt("Vector elements", &workloadElements, 4096, 1048576);
		ImGui::SliderInt("Benchmark iterations", &workloadIterations, 1, 2048);
		if (ImGui::Button("Run", ImVec2(96.0f, 0.0f))) {
			runBackendCheck();
		}
		ImGui::SameLine();
		if (lastRunHadError) {
			ImGui::TextColored(ImVec4(1.0f, 0.35f, 0.25f, 1.0f), "Backend: %s", lastBackendName.c_str());
		} else {
			ImGui::Text("Backend: %s", lastBackendName.c_str());
		}

		ImGui::Separator();
		for (const auto & line : lines) {
			if (line.rfind("runtime error:", 0) == 0 || line.rfind("graph error:", 0) == 0) {
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
