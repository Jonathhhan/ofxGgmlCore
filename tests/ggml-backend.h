#pragma once

#include "ggml.h"

#include <cstring>
#include <string>

struct ggml_backend {
	std::string name = "CPU";
};

struct ggml_backend_buffer {
	ggml_context * ctx = nullptr;
};

using ggml_backend_t = ggml_backend *;
using ggml_backend_buffer_t = ggml_backend_buffer *;

inline const char * ggml_backend_name(ggml_backend_t backend) {
	return backend ? backend->name.c_str() : "";
}

inline void ggml_backend_free(ggml_backend_t backend) {
	delete backend;
}

inline ggml_backend_buffer_t ggml_backend_alloc_ctx_tensors(ggml_context * ctx, ggml_backend_t backend) {
	if (!ctx || !backend) return nullptr;
	auto * buffer = new ggml_backend_buffer();
	buffer->ctx = ctx;
	return buffer;
}

inline void ggml_backend_buffer_free(ggml_backend_buffer_t buffer) {
	delete buffer;
}

inline ggml_status ggml_backend_graph_compute(ggml_backend_t backend, ggml_cgraph * graph) {
	if (!backend || !graph) return GGML_STATUS_FAILED;
	for (ggml_tensor * tensor : graph->nodes) {
		ggml_compute_tensor(tensor);
	}
	return GGML_STATUS_SUCCESS;
}

inline void ggml_backend_tensor_set(ggml_tensor * tensor, const void * data, std::size_t offset, std::size_t bytes) {
	if (!tensor || !data || offset + bytes > tensor->data.size()) return;
	std::memcpy(tensor->data.data() + offset, data, bytes);
}

inline void ggml_backend_tensor_get(ggml_tensor * tensor, void * data, std::size_t offset, std::size_t bytes) {
	if (!tensor || !data || offset + bytes > tensor->data.size()) return;
	std::memcpy(data, tensor->data.data() + offset, bytes);
}
