#include "ofxGgmlGraph.h"

#if __has_include("ggml.h")
#include "ggml.h"
#define OFXGGML_HAS_GGML 1
#else
#define OFXGGML_HAS_GGML 0
#endif

#include <algorithm>
#include <utility>

#if OFXGGML_HAS_GGML
namespace {
ggml_type toGgmlType(ofxGgmlType type) {
	switch (type) {
	case ofxGgmlType::F32:
		return GGML_TYPE_F32;
	case ofxGgmlType::F16:
		return GGML_TYPE_F16;
	case ofxGgmlType::I32:
		return GGML_TYPE_I32;
	case ofxGgmlType::I16:
		return GGML_TYPE_I16;
	case ofxGgmlType::I8:
		return GGML_TYPE_I8;
	}
	return GGML_TYPE_F32;
}
}
#endif

ofxGgmlGraph::ofxGgmlGraph(std::size_t memoryBytes)
	: memoryBytes(std::max<std::size_t>(memoryBytes, 1024u * 1024u)) {
#if OFXGGML_HAS_GGML
	ggml_init_params params {};
	params.mem_size = this->memoryBytes;
	params.mem_buffer = nullptr;
	params.no_alloc = true;
	ctx = ggml_init(params);
#endif
}

ofxGgmlGraph::~ofxGgmlGraph() {
	release();
}

ofxGgmlGraph::ofxGgmlGraph(ofxGgmlGraph && other) noexcept
	: ctx(std::exchange(other.ctx, nullptr))
	, graph(std::exchange(other.graph, nullptr))
	, memoryBytes(std::exchange(other.memoryBytes, 0)) {}

ofxGgmlGraph & ofxGgmlGraph::operator=(ofxGgmlGraph && other) noexcept {
	if (this != &other) {
		release();
		ctx = std::exchange(other.ctx, nullptr);
		graph = std::exchange(other.graph, nullptr);
		memoryBytes = std::exchange(other.memoryBytes, 0);
	}
	return *this;
}

ofxGgmlTensor ofxGgmlGraph::tensor1d(ofxGgmlType type, int64_t ne0) {
#if OFXGGML_HAS_GGML
	if (!ctx || ne0 <= 0) return {};
	return ofxGgmlTensor(ggml_new_tensor_1d(ctx, toGgmlType(type), ne0));
#else
	(void) type;
	(void) ne0;
	return {};
#endif
}

ofxGgmlTensor ofxGgmlGraph::tensor2d(ofxGgmlType type, int64_t ne0, int64_t ne1) {
#if OFXGGML_HAS_GGML
	if (!ctx || ne0 <= 0 || ne1 <= 0) return {};
	return ofxGgmlTensor(ggml_new_tensor_2d(ctx, toGgmlType(type), ne0, ne1));
#else
	(void) type;
	(void) ne0;
	(void) ne1;
	return {};
#endif
}

ofxGgmlTensor ofxGgmlGraph::add(ofxGgmlTensor a, ofxGgmlTensor b) {
#if OFXGGML_HAS_GGML
	if (!ctx || !a || !b) return {};
	return ofxGgmlTensor(ggml_add(ctx, a.raw(), b.raw()));
#else
	(void) a;
	(void) b;
	return {};
#endif
}

ofxGgmlTensor ofxGgmlGraph::mul(ofxGgmlTensor a, ofxGgmlTensor b) {
#if OFXGGML_HAS_GGML
	if (!ctx || !a || !b) return {};
	return ofxGgmlTensor(ggml_mul(ctx, a.raw(), b.raw()));
#else
	(void) a;
	(void) b;
	return {};
#endif
}

ofxGgmlTensor ofxGgmlGraph::matmul(ofxGgmlTensor a, ofxGgmlTensor b) {
#if OFXGGML_HAS_GGML
	if (!ctx || !a || !b) return {};
	return ofxGgmlTensor(ggml_mul_mat(ctx, a.raw(), b.raw()));
#else
	(void) a;
	(void) b;
	return {};
#endif
}

void ofxGgmlGraph::build(ofxGgmlTensor output) {
#if OFXGGML_HAS_GGML
	if (!ctx || !output) {
		graph = nullptr;
		return;
	}
	graph = ggml_new_graph(ctx);
	ggml_build_forward_expand(graph, output.raw());
#else
	(void) output;
#endif
}

void ofxGgmlGraph::build(std::initializer_list<ofxGgmlTensor> outputs) {
	build(std::vector<ofxGgmlTensor>(outputs));
}

void ofxGgmlGraph::build(const std::vector<ofxGgmlTensor> & outputs) {
#if OFXGGML_HAS_GGML
	if (!ctx || outputs.empty()) {
		graph = nullptr;
		return;
	}
	graph = ggml_new_graph(ctx);
	for (const auto & output : outputs) {
		if (output) ggml_build_forward_expand(graph, output.raw());
	}
#else
	(void) outputs;
#endif
}

bool ofxGgmlGraph::isBuilt() const {
#if OFXGGML_HAS_GGML
	return graph && ggml_graph_n_nodes(graph) > 0;
#else
	return false;
#endif
}

int ofxGgmlGraph::nodeCount() const {
#if OFXGGML_HAS_GGML
	return graph ? ggml_graph_n_nodes(graph) : 0;
#else
	return 0;
#endif
}

ggml_context * ofxGgmlGraph::context() const {
	return ctx;
}

ggml_cgraph * ofxGgmlGraph::raw() const {
	return graph;
}

void ofxGgmlGraph::release() {
#if OFXGGML_HAS_GGML
	if (ctx) {
		ggml_free(ctx);
		ctx = nullptr;
		graph = nullptr;
	}
#endif
}
