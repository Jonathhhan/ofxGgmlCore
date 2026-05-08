#pragma once

#include "../core/ofxGgmlTypes.h"

#include <cstddef>
#include <cstdint>
#include <vector>

struct ggml_tensor;

class ofxGgmlTensor {
public:
	ofxGgmlTensor() = default;
	explicit ofxGgmlTensor(ggml_tensor * tensor);

	explicit operator bool() const;
	bool isValid() const;

	ggml_tensor * raw() const;
	ofxGgmlType type() const;
	int dims() const;
	int64_t extent(int dim) const;
	std::size_t bytes() const;
	std::size_t elementCount() const;

private:
	ggml_tensor * tensor = nullptr;
};
