#pragma once

#include "ggml-backend.h"

inline ggml_backend_t ggml_backend_cpu_init() {
	return new ggml_backend();
}
