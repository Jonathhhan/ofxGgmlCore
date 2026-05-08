#pragma once

#include <cstddef>
#include <cstdint>
#include <string>

enum class ofxGgmlBackend {
	Cpu,
	Cuda,
	Vulkan,
	Metal
};

enum class ofxGgmlType {
	F32,
	F16,
	I32,
	I16,
	I8
};

enum class ofxGgmlRuntimeState {
	Uninitialized,
	Ready,
	Error
};

struct ofxGgmlRuntimeSettings {
	ofxGgmlBackend preferredBackend = ofxGgmlBackend::Cpu;
	bool allowCpuFallback = true;
	int threads = 0;
};

struct ofxGgmlDeviceInfo {
	std::string name;
	ofxGgmlBackend backend = ofxGgmlBackend::Cpu;
	std::size_t memoryBytes = 0;
	bool available = false;
};

struct ofxGgmlComputeResult {
	bool success = false;
	float elapsedMs = 0.0f;
	std::string error;
};
