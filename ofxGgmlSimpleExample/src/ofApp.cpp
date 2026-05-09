#include "ofApp.h"

#include <sstream>

namespace {

std::string backendLabel(ofxGgmlBackend backend) {
	switch (backend) {
	case ofxGgmlBackend::Auto: return "Auto";
	case ofxGgmlBackend::Cpu: return "CPU";
	case ofxGgmlBackend::Cuda: return "CUDA";
	case ofxGgmlBackend::Vulkan: return "Vulkan";
	case ofxGgmlBackend::Metal: return "Metal";
	}
	return "Unknown";
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

} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml rewrite");
	ofBackground(12);

	auto result = runtime.setup();
	lines.clear();
	lines.push_back("ofxGgml rewrite main");
	lines.push_back(result ? "runtime ready: " + runtime.backendName() : "runtime error: " + result.error().message);
	lines.push_back("preferred backend: Auto");
	lines.push_back("devices:");
	for (const auto & device : runtime.listDevices()) {
		lines.push_back("  " + backendLabel(device.backend) + ": " + device.name + formatBytes(device.memoryBytes));
	}
	lines.push_back("legacy-full keeps the previous broad framework.");
}

void ofApp::draw() {
	ofSetColor(240);
	int y = 40;
	for (const auto & line : lines) {
		ofDrawBitmapString(line, 32, y);
		y += 24;
	}
}
