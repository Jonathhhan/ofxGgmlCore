#pragma once

#include "ggml-backend.h"

inline ggml_backend_t ggml_backend_cpu_init() {
	auto * backend = new ggml_backend();
	++ggml_test_backend_live_count();
	return backend;
}

inline bool ggml_backend_is_cpu(ggml_backend_t backend) {
	return backend && backend->name == "CPU";
}

inline void ggml_backend_cpu_set_n_threads(ggml_backend_t backend, int n_threads) {
	if (!backend) return;
	backend->threads = n_threads;
	ggml_test_backend_last_thread_count() = n_threads;
}
