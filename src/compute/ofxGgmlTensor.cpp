#include "ofxGgmlTensor.h"

#if __has_include("ggml.h")
#include "ggml.h"
#define OFXGGML_HAS_GGML 1
#else
#define OFXGGML_HAS_GGML 0
#endif

#if OFXGGML_HAS_GGML
namespace {
ofxGgmlType fromGgmlType(ggml_type type) {
	switch (type) {
	case GGML_TYPE_F32:
		return ofxGgmlType::F32;
	case GGML_TYPE_F16:
		return ofxGgmlType::F16;
	case GGML_TYPE_I32:
		return ofxGgmlType::I32;
	case GGML_TYPE_I16:
		return ofxGgmlType::I16;
	case GGML_TYPE_I8:
		return ofxGgmlType::I8;
	default:
		return ofxGgmlType::F32;
	}
}
}
#endif

ofxGgmlTensor::ofxGgmlTensor(ggml_tensor * tensor)
	: tensor(tensor) {}

ofxGgmlTensor::operator bool() const {
	return isValid();
}

bool ofxGgmlTensor::isValid() const {
	return tensor != nullptr;
}

ggml_tensor * ofxGgmlTensor::getRaw() const {
	return tensor;
}

ofxGgmlType ofxGgmlTensor::getType() const {
#if OFXGGML_HAS_GGML
	return tensor ? fromGgmlType(tensor->type) : ofxGgmlType::F32;
#else
	return ofxGgmlType::F32;
#endif
}

int ofxGgmlTensor::getNumDims() const {
#if OFXGGML_HAS_GGML
	return tensor ? ggml_n_dims(tensor) : 0;
#else
	return 0;
#endif
}

int64_t ofxGgmlTensor::getExtent(int dim) const {
#if OFXGGML_HAS_GGML
	if (!tensor || dim < 0 || dim >= GGML_MAX_DIMS) return 0;
	return tensor->ne[dim];
#else
	(void) dim;
	return 0;
#endif
}

std::size_t ofxGgmlTensor::getByteSize() const {
#if OFXGGML_HAS_GGML
	return tensor ? ggml_nbytes(tensor) : 0;
#else
	return 0;
#endif
}

std::size_t ofxGgmlTensor::getElementCount() const {
#if OFXGGML_HAS_GGML
	return tensor ? static_cast<std::size_t>(ggml_nelements(tensor)) : 0;
#else
	return 0;
#endif
}
