#include "ofApp.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <exception>
#include <sstream>
#include <thread>
#include <utility>

namespace {

constexpr const char * LogModule = "ofxGgmlCoreExample";

std::string backendLabel(ofxGgmlBackend backend) {
	return ofxGgmlGetBackendName(backend);
}

bool backendNameMatches(ofxGgmlBackend backend, const std::string & activeName) {
	if (backend == ofxGgmlBackend::Auto) {
		return true;
	}
	const std::string expected = backendLabel(backend);
	return activeName.rfind(expected, 0) == 0;
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

void appendLine(std::vector<std::string> & lines, const std::string & line, bool warning = false) {
	lines.push_back(line);
	if (warning) {
		ofLogWarning(LogModule) << line;
	} else {
		ofLogNotice(LogModule) << line;
	}
}

} // namespace

void ofApp::BackendWorker::start() {
	if (!isThreadRunning()) {
		startThread();
	}
}

void ofApp::BackendWorker::stop() {
	jobs.close();
	waitForThread(true);
	results.close();
}

bool ofApp::BackendWorker::submit(BackendJob job) {
	if (busy.exchange(true)) {
		return false;
	}
	const bool sent = jobs.send(std::move(job));
	if (!sent) {
		busy.store(false);
	}
	return sent;
}

bool ofApp::BackendWorker::tryReceive(BackendResult & result) {
	return results.tryReceive(result);
}

bool ofApp::BackendWorker::isBusy() const {
	return busy.load();
}

ofApp::BackendResult ofApp::BackendWorker::runJob(const BackendJob & job) {
	BackendResult completed;
	completed.requestedBackend = job.requestedBackend;

	std::ostringstream threadLabel;
	threadLabel << std::this_thread::get_id();
	appendLine(completed.lines, "execution: ofThread worker " + threadLabel.str());

	ofxGgmlBackend requestedBackend = job.requestedBackend;
	if (job.discoverBackends) {
		ofxGgml discoveryRuntime;
		ofxGgmlRuntimeSettings discoverySettings;
		discoverySettings.preferredBackend = ofxGgmlBackend::Auto;
		discoverySettings.allowCpuFallback = true;
		const auto discoveryResult = discoveryRuntime.setup(discoverySettings);
		if (!discoveryResult) {
			completed.hadError = true;
			appendLine(completed.lines, "backend discovery error: " + discoveryResult.error().message, true);
			return completed;
		}

		for (const auto & device : discoveryRuntime.getDevices()) {
			if (std::find(completed.availableBackends.begin(), completed.availableBackends.end(), device.backend) == completed.availableBackends.end()) {
				completed.availableBackends.push_back(device.backend);
			}
		}
		discoveryRuntime.close();

		if (job.preferAccelerator) {
			const std::vector<ofxGgmlBackend> preferredOrder = {
				ofxGgmlBackend::CUDA,
				ofxGgmlBackend::Vulkan,
				ofxGgmlBackend::Metal,
				ofxGgmlBackend::OpenCL,
				ofxGgmlBackend::CPU
			};
			for (const auto preferred : preferredOrder) {
				if (std::find(completed.availableBackends.begin(), completed.availableBackends.end(), preferred) != completed.availableBackends.end()) {
					requestedBackend = preferred;
					break;
				}
			}
		}
	}

	completed.requestedBackend = requestedBackend;
	const int elementCount = std::max(job.elementCount, 4);
	const int iterationCount = std::max(job.iterationCount, 1);

	ofxGgml runtime;
	ofxGgmlRuntimeSettings settings;
	settings.preferredBackend = requestedBackend;
	settings.allowCpuFallback = job.allowCpuFallback;
	appendLine(completed.lines, "requested backend: " + backendLabel(requestedBackend));
	appendLine(completed.lines, std::string("CPU fallback: ") + (job.allowCpuFallback ? "enabled" : "disabled"));

	const auto setupResult = runtime.setup(settings);
	if (!setupResult) {
		completed.hadError = true;
		appendLine(completed.lines, "runtime error: " + setupResult.error().message, true);
		return completed;
	}

	completed.activeBackendName = runtime.getBackendName();
	completed.usedFallback = !backendNameMatches(requestedBackend, completed.activeBackendName);
	appendLine(completed.lines, "runtime ready: " + completed.activeBackendName);
	if (completed.usedFallback) {
		appendLine(completed.lines, "fallback used: requested " + backendLabel(requestedBackend) + ", active " + completed.activeBackendName, true);
	}
	appendLine(completed.lines, "devices:");
	for (const auto & device : runtime.getDevices()) {
		if (std::find(completed.availableBackends.begin(), completed.availableBackends.end(), device.backend) == completed.availableBackends.end()) {
			completed.availableBackends.push_back(device.backend);
		}
		appendLine(completed.lines, "  " + backendLabel(device.backend) + ": " + device.name + formatBytes(device.memoryBytes));
	}

	constexpr int graphOpCount = 5;
	ofxGgmlGraph graph(64u * 1024u * 1024u);
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
	for (int i = 0; i < elementCount; ++i) {
		left[static_cast<std::size_t>(i)] = static_cast<float>((i % 97) + 1);
		right[static_cast<std::size_t>(i)] = static_cast<float>((i % 31) + 1) * 0.25f;
	}

	std::string graphError;
	const auto allocateResult = runtime.allocate(graph);
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
	float maxAbsoluteError = 0.0f;
	float maxRelativeError = 0.0f;
	constexpr float validationTolerance = 0.00001f;
	if (graphError.empty()) {
		std::vector<float> output(static_cast<std::size_t>(elementCount));
		const auto getResult = runtime.getData(resultTensor, output.data(), output.size() * sizeof(float));
		if (!getResult) {
			graphError = getResult.error().message;
		} else {
			for (int i = 0; i < elementCount; ++i) {
				const float leftValue = left[static_cast<std::size_t>(i)];
				const float rightValue = right[static_cast<std::size_t>(i)];
				const float sumValue = leftValue + rightValue;
				const float mixedValue = sumValue * rightValue;
				const float boostedValue = mixedValue + leftValue;
				const float expected = (boostedValue * sumValue) + mixedValue;
				const float absoluteError = std::abs(output[static_cast<std::size_t>(i)] - expected);
				const float relativeError = absoluteError / std::max(1.0f, std::abs(expected));
				maxAbsoluteError = std::max(maxAbsoluteError, absoluteError);
				maxRelativeError = std::max(maxRelativeError, relativeError);
			}
			if (maxRelativeError > validationTolerance) {
				graphError = "result validation failed: max relative error " + std::to_string(maxRelativeError) +
					" exceeds tolerance " + std::to_string(validationTolerance);
			}
		}
	}

	if (!graphError.empty()) {
		completed.hadError = true;
		appendLine(completed.lines, "graph error: " + graphError, true);
		return completed;
	}

	const double averageComputeMs = computeMs / static_cast<double>(iterationCount);
	const double elementOps = static_cast<double>(elementCount) * static_cast<double>(graphOpCount) * static_cast<double>(iterationCount);
	appendLine(completed.lines, "workload: " + std::to_string(elementCount) + " F32 elements x " + std::to_string(graphOpCount) + " graph ops x " + std::to_string(iterationCount) + " iterations");
	appendLine(completed.lines, "approx element ops: " + std::to_string(static_cast<long long>(elementOps)));
	appendLine(completed.lines, "result check: passed (max abs error " + std::to_string(maxAbsoluteError) +
		", max relative error " + std::to_string(maxRelativeError) +
		", tolerance " + std::to_string(validationTolerance) + ")");
	appendLine(completed.lines, "backend compute time: " + formatMs(computeMs) + " total, " + formatMs(averageComputeMs) + " average");
	appendLine(completed.lines, "wall time: " + formatMs(wallMs));
	return completed;
}

void ofApp::BackendWorker::threadedFunction() {
	BackendJob job;
	while (jobs.receive(job)) {
		BackendResult completed;
		try {
			completed = runJob(job);
		} catch (const std::exception & error) {
			completed.requestedBackend = job.requestedBackend;
			completed.hadError = true;
			appendLine(completed.lines, std::string("worker error: ") + error.what(), true);
		} catch (...) {
			completed.requestedBackend = job.requestedBackend;
			completed.hadError = true;
			appendLine(completed.lines, "worker error: unknown failure", true);
		}
		results.send(std::move(completed));
		busy.store(false);
	}
	busy.store(false);
}

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml Core Example");
	ofBackground(12);
	gui.setup(nullptr, false);

	backendOptions = { ofxGgmlBackend::Auto };
	lines = { "Discovering devices and starting the benchmark on an ofThread worker..." };
	backendWorker.start();
	requestBackendCheck(true);
}

void ofApp::update() {
	BackendResult completed;
	while (backendWorker.tryReceive(completed)) {
		applyResult(std::move(completed));
	}
}

void ofApp::exit() {
	backendWorker.stop();
}

ofxGgmlBackend ofApp::getSelectedBackend() const {
	if (selectedBackendIndex < 0 || selectedBackendIndex >= static_cast<int>(backendOptions.size())) {
		return ofxGgmlBackend::Auto;
	}
	return backendOptions[static_cast<std::size_t>(selectedBackendIndex)];
}

void ofApp::requestBackendCheck(bool discoverBackends) {
	BackendJob job;
	job.requestedBackend = discoverBackends ? ofxGgmlBackend::Auto : getSelectedBackend();
	job.discoverBackends = discoverBackends;
	job.preferAccelerator = discoverBackends;
	job.allowCpuFallback = allowCpuFallback;
	job.elementCount = workloadElements;
	job.iterationCount = workloadIterations;
	if (!backendWorker.submit(std::move(job))) {
		ofLogWarning(LogModule) << "Inference request ignored because the worker is already busy";
	}
}

void ofApp::applyResult(BackendResult result) {
	availableBackends = std::move(result.availableBackends);
	backendOptions = { ofxGgmlBackend::Auto };
	for (const auto backend : availableBackends) {
		if (std::find(backendOptions.begin(), backendOptions.end(), backend) == backendOptions.end()) {
			backendOptions.push_back(backend);
		}
	}

	selectedBackendIndex = 0;
	const auto selected = std::find(backendOptions.begin(), backendOptions.end(), result.requestedBackend);
	if (selected != backendOptions.end()) {
		selectedBackendIndex = static_cast<int>(std::distance(backendOptions.begin(), selected));
	}

	lastRunHadError = result.hadError;
	lastRunUsedFallback = result.usedFallback;
	lastRequestedBackendName = backendLabel(result.requestedBackend);
	lastBackendName = std::move(result.activeBackendName);
	lines = std::move(result.lines);
}

void ofApp::draw() {
	ofBackground(12);

	gui.begin();
	ImGui::SetNextWindowPos(ImVec2(24.0f, 24.0f), ImGuiCond_Once);
	ImGui::SetNextWindowSize(ImVec2(760.0f, 460.0f), ImGuiCond_Once);
	if (ImGui::Begin("ofxGgml Core Example")) {
		ImGui::TextUnformatted("Runtime");
		ImGui::Separator();

		const bool workerBusy = backendWorker.isBusy();
		if (workerBusy) {
			ImGui::TextColored(ImVec4(0.35f, 0.75f, 1.0f, 1.0f), "Inference running on ofThread worker...");
		}
		ImGui::BeginDisabled(workerBusy);
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
		ImGui::SameLine();
		if (ImGui::Button("Refresh")) {
			requestBackendCheck(true);
		}
		std::string availableSummary;
		for (std::size_t i = 0; i < availableBackends.size(); ++i) {
			availableSummary += (i > 0 ? ", " : "");
			availableSummary += ofxGgmlGetBackendName(availableBackends[i]);
		}
		if (availableBackends.empty()) {
			ImGui::TextDisabled("Available: none detected");
		} else {
			ImGui::Text("Available: %s", availableSummary.c_str());
		}
		ImGui::Checkbox("Allow CPU fallback", &allowCpuFallback);
		ImGui::SliderInt("Vector elements", &workloadElements, 4096, 1048576);
		ImGui::SliderInt("Benchmark iterations", &workloadIterations, 1, 2048);
		if (ImGui::Button("Run", ImVec2(96.0f, 0.0f))) {
			requestBackendCheck(false);
		}
		ImGui::EndDisabled();
		ImGui::SameLine();
		if (lastRunHadError) {
			ImGui::TextColored(ImVec4(1.0f, 0.35f, 0.25f, 1.0f), "Requested: %s | Active: %s", lastRequestedBackendName.c_str(), lastBackendName.c_str());
		} else if (lastRunUsedFallback) {
			ImGui::TextColored(ImVec4(1.0f, 0.75f, 0.2f, 1.0f), "Requested: %s | Active: %s (fallback)", lastRequestedBackendName.c_str(), lastBackendName.c_str());
		} else {
			ImGui::Text("Requested: %s | Active: %s", lastRequestedBackendName.c_str(), lastBackendName.c_str());
		}

		ImGui::Separator();
		for (const auto & line : lines) {
			if (line.rfind("backend discovery error:", 0) == 0 || line.rfind("runtime error:", 0) == 0 ||
				line.rfind("graph error:", 0) == 0 || line.rfind("worker error:", 0) == 0) {
				ImGui::TextColored(ImVec4(1.0f, 0.35f, 0.25f, 1.0f), "%s", line.c_str());
			} else if (line.rfind("fallback used:", 0) == 0) {
				ImGui::TextColored(ImVec4(1.0f, 0.75f, 0.2f, 1.0f), "%s", line.c_str());
			} else {
				ImGui::TextWrapped("%s", line.c_str());
			}
		}
	}
	ImGui::End();
	gui.end();
	gui.draw();
}
