#pragma once

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>
#include <utility>

enum class ofxGgmlBackend {
	Auto,
	CPU,
	CUDA,
	Vulkan,
	Metal,
	OpenCL
};

inline const char * ofxGgmlGetBackendName(ofxGgmlBackend backend) {
	switch (backend) {
	case ofxGgmlBackend::Auto: return "Auto";
	case ofxGgmlBackend::CPU: return "CPU";
	case ofxGgmlBackend::CUDA: return "CUDA";
	case ofxGgmlBackend::Vulkan: return "Vulkan";
	case ofxGgmlBackend::Metal: return "Metal";
	case ofxGgmlBackend::OpenCL: return "OpenCL";
	}
	return "unknown";
}

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

// Thread configuration mode
enum class ofxGgmlThreadMode {
	// Legacy single thread count - all agents share same thread pool
	Shared,
	// Per-agent thread pool - each agent can have different thread configuration
	PerAgent
};

struct ofxGgmlAgentThreadConfig {
	int threads = 0;  // Number of threads for this agent
	bool useThreadpool = false;  // Whether to use thread pool instead of simple thread count
};

struct ofxGgmlRuntimeSettings {
	ofxGgmlBackend preferredBackend = ofxGgmlBackend::Auto;
	bool allowCpuFallback = true;
	int deviceIndex = 0;
	int threads = 0;
	
	// Thread configuration mode
	ofxGgmlThreadMode threadMode = ofxGgmlThreadMode::Shared;
	
	// Per-agent thread configuration (used when threadMode == PerAgent)
	// Map of agent ID to thread config
	std::vector<std::pair<std::string, ofxGgmlAgentThreadConfig>> agentThreads;
	
	std::string backendName;
};

struct ofxGgmlDeviceInfo {
	std::string name;
	ofxGgmlBackend backend = ofxGgmlBackend::CPU;
	std::size_t memoryBytes = 0;
	bool available = false;
};

struct ofxGgmlComputeResult {
	bool success = false;
	float elapsedMs = 0.0f;
	std::string error;

	explicit operator bool() const {
		return isOk();
	}

	bool isOk() const {
		return success;
	}

	bool isError() const {
		return !isOk();
	}
};
