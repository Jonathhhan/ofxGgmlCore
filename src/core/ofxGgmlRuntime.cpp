#include "ofxGgmlRuntime.h"

#include "../compute/ofxGgmlGraph.h"
#include "../compute/ofxGgmlTensor.h"

#if __has_include("ggml.h")
#include "ggml.h"
#include "ggml-alloc.h"
#include "ggml-backend.h"
#include "ggml-cpu.h"
#define OFXGGML_HAS_GGML 1
#else
#define OFXGGML_HAS_GGML 0
#endif

#include <chrono>
#include <utility>

struct ofxGgmlRuntime::Impl {
	ofxGgmlRuntimeState state = ofxGgmlRuntimeState::Uninitialized;
	ofxGgmlRuntimeSettings settings;
#if OFXGGML_HAS_GGML
	ggml_backend_t backend = nullptr;
	ggml_backend_buffer_t buffer = nullptr;
#endif
};

ofxGgmlRuntime::ofxGgmlRuntime()
	: impl(std::make_unique<Impl>()) {}

ofxGgmlRuntime::~ofxGgmlRuntime() {
	close();
}

ofxGgmlRuntime::ofxGgmlRuntime(ofxGgmlRuntime &&) noexcept = default;
ofxGgmlRuntime & ofxGgmlRuntime::operator=(ofxGgmlRuntime &&) noexcept = default;

ofxGgmlResult<void> ofxGgmlRuntime::setup(const ofxGgmlRuntimeSettings & settings) {
	close();
	impl->settings = settings;
#if OFXGGML_HAS_GGML
	impl->backend = ggml_backend_cpu_init();
	if (!impl->backend) {
		impl->state = ofxGgmlRuntimeState::Error;
		return ofxGgmlResult<void>::failure("failed to initialize ggml CPU backend");
	}
	impl->state = ofxGgmlRuntimeState::Ready;
	return ofxGgmlResult<void>::success();
#else
	impl->state = ofxGgmlRuntimeState::Error;
	return ofxGgmlResult<void>::failure("ggml headers are not installed; run scripts/setup-ggml.ps1");
#endif
}

void ofxGgmlRuntime::close() {
#if OFXGGML_HAS_GGML
	if (impl && impl->buffer) {
		ggml_backend_buffer_free(impl->buffer);
		impl->buffer = nullptr;
	}
	if (impl && impl->backend) {
		ggml_backend_free(impl->backend);
		impl->backend = nullptr;
	}
#endif
	if (impl) {
		impl->state = ofxGgmlRuntimeState::Uninitialized;
	}
}

bool ofxGgmlRuntime::isReady() const {
#if OFXGGML_HAS_GGML
	return impl && impl->state == ofxGgmlRuntimeState::Ready && impl->backend;
#else
	return false;
#endif
}

ofxGgmlRuntimeState ofxGgmlRuntime::state() const {
	return impl ? impl->state : ofxGgmlRuntimeState::Uninitialized;
}

std::string ofxGgmlRuntime::backendName() const {
#if OFXGGML_HAS_GGML
	if (!impl || !impl->backend) return {};
	const char * name = ggml_backend_name(impl->backend);
	return name ? name : "";
#else
	return {};
#endif
}

std::vector<ofxGgmlDeviceInfo> ofxGgmlRuntime::listDevices() const {
	return { { "CPU", ofxGgmlBackend::Cpu, 0, true } };
}

ofxGgmlResult<void> ofxGgmlRuntime::allocate(ofxGgmlGraph & graph) {
#if OFXGGML_HAS_GGML
	if (!isReady()) return ofxGgmlResult<void>::failure("runtime is not ready");
	if (!graph.isBuilt()) return ofxGgmlResult<void>::failure("graph is not built");
	if (impl->buffer) {
		ggml_backend_buffer_free(impl->buffer);
		impl->buffer = nullptr;
	}
	impl->buffer = ggml_backend_alloc_ctx_tensors(graph.context(), impl->backend);
	if (!impl->buffer) return ofxGgmlResult<void>::failure("failed to allocate graph tensors");
	return ofxGgmlResult<void>::success();
#else
	(void) graph;
	return ofxGgmlResult<void>::failure("ggml is not installed");
#endif
}

ofxGgmlComputeResult ofxGgmlRuntime::compute(ofxGgmlGraph & graph) {
	ofxGgmlComputeResult result;
#if OFXGGML_HAS_GGML
	if (!isReady()) {
		result.error = "runtime is not ready";
		return result;
	}
	if (!graph.isBuilt()) {
		result.error = "graph is not built";
		return result;
	}
	const auto start = std::chrono::steady_clock::now();
	const ggml_status status = ggml_backend_graph_compute(impl->backend, graph.raw());
	const auto stop = std::chrono::steady_clock::now();
	result.elapsedMs = std::chrono::duration<float, std::milli>(stop - start).count();
	result.success = status == GGML_STATUS_SUCCESS;
	if (!result.success) {
		result.error = "ggml compute failed";
	}
#else
	(void) graph;
	result.error = "ggml is not installed";
#endif
	return result;
}

ofxGgmlResult<void> ofxGgmlRuntime::setData(ofxGgmlTensor tensor, const void * data, std::size_t bytes) {
#if OFXGGML_HAS_GGML
	if (!tensor || !data) return ofxGgmlResult<void>::failure("invalid tensor data");
	if (bytes != tensor.bytes()) return ofxGgmlResult<void>::failure("tensor byte count mismatch");
	ggml_backend_tensor_set(tensor.raw(), data, 0, bytes);
	return ofxGgmlResult<void>::success();
#else
	(void) tensor;
	(void) data;
	(void) bytes;
	return ofxGgmlResult<void>::failure("ggml is not installed");
#endif
}

ofxGgmlResult<void> ofxGgmlRuntime::getData(ofxGgmlTensor tensor, void * data, std::size_t bytes) {
#if OFXGGML_HAS_GGML
	if (!tensor || !data) return ofxGgmlResult<void>::failure("invalid tensor data");
	if (bytes != tensor.bytes()) return ofxGgmlResult<void>::failure("tensor byte count mismatch");
	ggml_backend_tensor_get(tensor.raw(), data, 0, bytes);
	return ofxGgmlResult<void>::success();
#else
	(void) tensor;
	(void) data;
	(void) bytes;
	return ofxGgmlResult<void>::failure("ggml is not installed");
#endif
}
