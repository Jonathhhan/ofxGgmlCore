#include "ofxGgmlTensor.h"

#if __has_include("ggml.h")
#include "ggml.h"
#define OFXGGML_HAS_GGML 1
#else
#define OFXGGML_HAS_GGML 0
#endif

ofxGgmlTensor::ofxGgmlTensor(ggml_tensor * tensor)
	: tensor(tensor) {}

ofxGgmlTensor::operator bool() const {
	return isValid();
}

bool ofxGgmlTensor::isValid() const {
	return tensor != nullptr;
}

ggml_tensor * ofxGgmlTensor::raw() const {
	return tensor;
}

ofxGgmlType ofxGgmlTensor::type() const {
#if OFXGGML_HAS_GGML
	return tensor ? static_cast<ofxGgmlType>(tensor->type) : ofxGgmlType::F32;
#else
	return ofxGgmlType::F32;
#endif
}

int ofxGgmlTensor::dims() const {
#if OFXGGML_HAS_GGML
	return tensor ? ggml_n_dims(tensor) : 0;
#else
	return 0;
#endif
}

int64_t ofxGgmlTensor::extent(int dim) const {
#if OFXGGML_HAS_GGML
	if (!tensor || dim < 0 || dim >= GGML_MAX_DIMS) return 0;
	return tensor->ne[dim];
#else
	(void) dim;
	return 0;
#endif
}

std::size_t ofxGgmlTensor::bytes() const {
#if OFXGGML_HAS_GGML
	return tensor ? ggml_nbytes(tensor) : 0;
#else
	return 0;
#endif
}

std::size_t ofxGgmlTensor::elementCount() const {
#if OFXGGML_HAS_GGML
	return tensor ? static_cast<std::size_t>(ggml_nelements(tensor)) : 0;
#else
	return 0;
#endif
}
