#include "ofxGgmlModel.h"

#if __has_include("gguf.h")
#include "gguf.h"
#define OFXGGML_HAS_GGUF 1
#else
#define OFXGGML_HAS_GGUF 0
#endif

#include <utility>

#if OFXGGML_HAS_GGUF
namespace {
uint64_t readUnsignedMetadataValue(const gguf_context * ctx, const std::string & key) {
	const int64_t keyId = gguf_find_key(ctx, key.c_str());
	if (keyId < 0) {
		return 0;
	}
	switch (gguf_get_kv_type(ctx, keyId)) {
	case GGUF_TYPE_UINT8:
		return gguf_get_val_u8(ctx, keyId);
	case GGUF_TYPE_UINT16:
		return gguf_get_val_u16(ctx, keyId);
	case GGUF_TYPE_UINT32:
		return gguf_get_val_u32(ctx, keyId);
	case GGUF_TYPE_UINT64:
		return gguf_get_val_u64(ctx, keyId);
	case GGUF_TYPE_INT8: {
		const auto value = gguf_get_val_i8(ctx, keyId);
		return value > 0 ? static_cast<uint64_t>(value) : 0;
	}
	case GGUF_TYPE_INT16: {
		const auto value = gguf_get_val_i16(ctx, keyId);
		return value > 0 ? static_cast<uint64_t>(value) : 0;
	}
	case GGUF_TYPE_INT32: {
		const auto value = gguf_get_val_i32(ctx, keyId);
		return value > 0 ? static_cast<uint64_t>(value) : 0;
	}
	case GGUF_TYPE_INT64: {
		const auto value = gguf_get_val_i64(ctx, keyId);
		return value > 0 ? static_cast<uint64_t>(value) : 0;
	}
	default:
		return 0;
	}
}
}
#endif

ofxGgmlResult<ofxGgmlModelInfo> ofxGgmlModel::inspect(const std::string & path) const {
	if (path.empty()) {
		return ofxGgmlResult<ofxGgmlModelInfo>::failure("model path is empty");
	}

#if OFXGGML_HAS_GGUF
	gguf_init_params params {};
	params.no_alloc = true;
	params.ctx = nullptr;
	gguf_context * ctx = gguf_init_from_file(path.c_str(), params);
	if (!ctx) {
		return ofxGgmlResult<ofxGgmlModelInfo>::failure("failed to read GGUF metadata: " + path);
	}

	ofxGgmlModelInfo info;
	info.path = path;
	info.tensorCount = static_cast<uint64_t>(gguf_get_n_tensors(ctx));
	info.metadataCount = static_cast<uint64_t>(gguf_get_n_kv(ctx));
	const int64_t archKey = gguf_find_key(ctx, "general.architecture");
	if (archKey >= 0) {
		const char * arch = gguf_get_val_str(ctx, archKey);
		info.architecture = arch ? arch : "";
	}
	if (!info.architecture.empty()) {
		info.layerCount = readUnsignedMetadataValue(ctx, info.architecture + ".block_count");
	}
	gguf_free(ctx);
	return ofxGgmlResult<ofxGgmlModelInfo>::success(std::move(info));
#else
	return ofxGgmlResult<ofxGgmlModelInfo>::failure("gguf headers are not installed; run scripts/setup-ggml.ps1");
#endif
}
