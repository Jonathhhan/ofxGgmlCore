#include "ofxGgmlModel.h"

#include "ggml.h"
#include "gguf.h"

#include <unordered_map>

// ---------------------------------------------------------------------------
// PIMPL
// ---------------------------------------------------------------------------

struct ofxGgmlModel::Impl {
	struct gguf_context * ggufCtx = nullptr;
	struct ggml_context * ggmlCtx = nullptr;
	std::string path;
	std::vector<std::string> metadataKeys;
	std::unordered_map<std::string, int64_t> metadataIndexByKey;
	std::vector<std::string> tensorNames;

	void clearCaches() {
		metadataKeys.clear();
		metadataIndexByKey.clear();
		tensorNames.clear();
	}

	void rebuildCaches() {
		clearCaches();
		if (!ggufCtx) {
			return;
		}

		const int64_t keyCount = static_cast<int64_t>(gguf_get_n_kv(ggufCtx));
		if (keyCount > 0) {
			metadataKeys.reserve(static_cast<size_t>(keyCount));
			metadataIndexByKey.reserve(static_cast<size_t>(keyCount));
			for (int64_t i = 0; i < keyCount; ++i) {
				const char * key = gguf_get_key(ggufCtx, static_cast<int>(i));
				metadataKeys.emplace_back(key ? key : "");
				metadataIndexByKey.emplace(metadataKeys.back(), i);
			}
		}

		const int64_t tensorCount = gguf_get_n_tensors(ggufCtx);
		if (tensorCount > 0) {
			tensorNames.reserve(static_cast<size_t>(tensorCount));
			for (int64_t i = 0; i < tensorCount; ++i) {
				const char * name = gguf_get_tensor_name(ggufCtx, i);
				tensorNames.emplace_back(name ? name : "");
			}
		}
	}
};

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

ofxGgmlModel::ofxGgmlModel()
	: m_impl(std::make_unique<Impl>()) {}

ofxGgmlModel::~ofxGgmlModel() {
	close();
}

bool ofxGgmlModel::load(const std::string & path) {
	close();

	struct ggml_context * dataCtx = nullptr;
	struct gguf_init_params params;
	params.no_alloc = false;
	params.ctx = &dataCtx;

	struct gguf_context * ggufCtx = gguf_init_from_file(path.c_str(), params);
	if (!ggufCtx || !dataCtx) {
		if (ggufCtx) {
			gguf_free(ggufCtx);
		}
		return false;
	}

	m_impl->ggufCtx = ggufCtx;
	m_impl->ggmlCtx = dataCtx;
	m_impl->path = path;
	m_impl->rebuildCaches();
	return true;
}

void ofxGgmlModel::close() {
	if (m_impl->ggufCtx) {
		gguf_free(m_impl->ggufCtx);
		m_impl->ggufCtx = nullptr;
	}
	if (m_impl->ggmlCtx) {
		ggml_free(m_impl->ggmlCtx);
		m_impl->ggmlCtx = nullptr;
	}
	m_impl->path.clear();
	m_impl->clearCaches();
}

bool ofxGgmlModel::isLoaded() const {
	return m_impl->ggufCtx != nullptr;
}

std::string ofxGgmlModel::getPath() const {
	return m_impl->path;
}

// ---------------------------------------------------------------------------
// Metadata
// ---------------------------------------------------------------------------

int64_t ofxGgmlModel::getNumMetadataKeys() const {
	return static_cast<int64_t>(m_impl->metadataKeys.size());
}

std::string ofxGgmlModel::getMetadataKey(int64_t index) const {
	const int64_t keyCount = static_cast<int64_t>(m_impl->metadataKeys.size());
	if (index < 0 || index >= keyCount) {
		return {};
	}
	return m_impl->metadataKeys[static_cast<size_t>(index)];
}

int64_t ofxGgmlModel::findMetadataKey(const std::string & key) const {
	if (!m_impl->ggufCtx) return -1;
	const auto it = m_impl->metadataIndexByKey.find(key);
	return it != m_impl->metadataIndexByKey.end() ? it->second : -1;
}

std::string ofxGgmlModel::getMetadataString(const std::string & key) const {
	if (!m_impl->ggufCtx) return {};

	const int64_t id = findMetadataKey(key);
	if (id < 0) return {};
	if (gguf_get_kv_type(m_impl->ggufCtx, id) != GGUF_TYPE_STRING) return {};

	const char * value = gguf_get_val_str(m_impl->ggufCtx, id);
	return value ? value : "";
}

int32_t ofxGgmlModel::getMetadataInt32(const std::string & key, int32_t defaultVal) const {
	if (!m_impl->ggufCtx) return defaultVal;

	const int64_t id = findMetadataKey(key);
	if (id < 0) return defaultVal;

	const enum gguf_type type = gguf_get_kv_type(m_impl->ggufCtx, id);
	if (type == GGUF_TYPE_INT32)  return gguf_get_val_i32(m_impl->ggufCtx, id);
	if (type == GGUF_TYPE_UINT32) return static_cast<int32_t>(gguf_get_val_u32(m_impl->ggufCtx, id));
	if (type == GGUF_TYPE_INT8)   return static_cast<int32_t>(gguf_get_val_i8(m_impl->ggufCtx, id));
	if (type == GGUF_TYPE_UINT8)  return static_cast<int32_t>(gguf_get_val_u8(m_impl->ggufCtx, id));
	if (type == GGUF_TYPE_INT16)  return static_cast<int32_t>(gguf_get_val_i16(m_impl->ggufCtx, id));
	if (type == GGUF_TYPE_UINT16) return static_cast<int32_t>(gguf_get_val_u16(m_impl->ggufCtx, id));
	return defaultVal;
}

uint32_t ofxGgmlModel::getMetadataUint32(const std::string & key, uint32_t defaultVal) const {
	if (!m_impl->ggufCtx) return defaultVal;

	const int64_t id = findMetadataKey(key);
	if (id < 0) return defaultVal;

	const enum gguf_type type = gguf_get_kv_type(m_impl->ggufCtx, id);
	if (type == GGUF_TYPE_UINT32) return gguf_get_val_u32(m_impl->ggufCtx, id);
	if (type == GGUF_TYPE_INT32)  return static_cast<uint32_t>(gguf_get_val_i32(m_impl->ggufCtx, id));
	return defaultVal;
}

float ofxGgmlModel::getMetadataFloat(const std::string & key, float defaultVal) const {
	if (!m_impl->ggufCtx) return defaultVal;

	const int64_t id = findMetadataKey(key);
	if (id < 0) return defaultVal;
	if (gguf_get_kv_type(m_impl->ggufCtx, id) != GGUF_TYPE_FLOAT32) return defaultVal;

	return gguf_get_val_f32(m_impl->ggufCtx, id);
}

// ---------------------------------------------------------------------------
// Tensor inspection
// ---------------------------------------------------------------------------

int64_t ofxGgmlModel::getNumTensors() const {
	return static_cast<int64_t>(m_impl->tensorNames.size());
}

std::string ofxGgmlModel::getTensorName(int64_t index) const {
	const int64_t tensorCount = static_cast<int64_t>(m_impl->tensorNames.size());
	if (index < 0 || index >= tensorCount) {
		return {};
	}
	return m_impl->tensorNames[static_cast<size_t>(index)];
}

ofxGgmlTensor ofxGgmlModel::getTensor(const std::string & name) {
	if (!m_impl->ggmlCtx) return ofxGgmlTensor();
	return ofxGgmlTensor(ggml_get_tensor(m_impl->ggmlCtx, name.c_str()));
}

std::vector<std::string> ofxGgmlModel::getTensorNames() const {
	return m_impl->tensorNames;
}

// ---------------------------------------------------------------------------
// Low-level access
// ---------------------------------------------------------------------------

struct gguf_context * ofxGgmlModel::ggufContext() {
	return m_impl->ggufCtx;
}

const struct gguf_context * ofxGgmlModel::ggufContext() const {
	return m_impl->ggufCtx;
}

struct ggml_context * ofxGgmlModel::ggmlContext() {
	return m_impl->ggmlCtx;
}

const struct ggml_context * ofxGgmlModel::ggmlContext() const {
	return m_impl->ggmlCtx;
}
