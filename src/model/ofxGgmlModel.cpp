#include "ofxGgmlModel.h"

#if __has_include("gguf.h")
#include "gguf.h"
#define OFXGGML_HAS_GGUF 1
#else
#define OFXGGML_HAS_GGUF 0
#endif

#include <utility>

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
	const int archKey = gguf_find_key(ctx, "general.architecture");
	if (archKey >= 0) {
		const char * arch = gguf_get_val_str(ctx, archKey);
		info.architecture = arch ? arch : "";
	}
	gguf_free(ctx);
	return ofxGgmlResult<ofxGgmlModelInfo>::success(std::move(info));
#else
	return ofxGgmlResult<ofxGgmlModelInfo>::failure("gguf headers are not installed; run scripts/setup-ggml.ps1");
#endif
}
