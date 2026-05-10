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
	ofxGgmlType getType() const;
	int getNumDims() const;
	int64_t getExtent(int dim) const;
	std::size_t getByteSize() const;
	std::size_t getElementCount() const;

private:
	ggml_tensor * tensor = nullptr;
};
