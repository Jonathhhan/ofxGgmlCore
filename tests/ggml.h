#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <memory>
#include <vector>

#define GGML_MAX_DIMS 4

enum ggml_type {
	GGML_TYPE_F32 = 0,
	GGML_TYPE_F16 = 1,
	GGML_TYPE_I32 = 32,
	GGML_TYPE_I16 = 16,
	GGML_TYPE_I8 = 8
};

enum ggml_status {
	GGML_STATUS_SUCCESS = 0,
	GGML_STATUS_FAILED = 1
};

struct ggml_tensor {
	enum class Op {
		None,
		Add,
		Mul,
		MatMul
	};

	ggml_type type = GGML_TYPE_F32;
	int n_dims = 0;
	int64_t ne[GGML_MAX_DIMS] = { 1, 1, 1, 1 };
	Op op = Op::None;
	ggml_tensor * src0 = nullptr;
	ggml_tensor * src1 = nullptr;
	std::vector<unsigned char> data;
};

struct ggml_cgraph {
	std::vector<ggml_tensor *> nodes;
};

struct ggml_context {
	std::vector<std::unique_ptr<ggml_tensor>> tensors;
	std::vector<std::unique_ptr<ggml_cgraph>> graphs;
};

struct ggml_init_params {
	std::size_t mem_size = 0;
	void * mem_buffer = nullptr;
	bool no_alloc = false;
};

inline std::size_t ggml_type_size(ggml_type type) {
	switch (type) {
	case GGML_TYPE_F32:
	case GGML_TYPE_I32:
		return 4;
	case GGML_TYPE_F16:
	case GGML_TYPE_I16:
		return 2;
	case GGML_TYPE_I8:
		return 1;
	}
	return 0;
}

inline ggml_context * ggml_init(ggml_init_params) {
	return new ggml_context();
}

inline void ggml_free(ggml_context * ctx) {
	delete ctx;
}

inline ggml_tensor * ggml_make_tensor(ggml_context * ctx, ggml_type type, int dims, int64_t ne0, int64_t ne1 = 1) {
	if (!ctx) return nullptr;
	auto tensor = std::make_unique<ggml_tensor>();
	tensor->type = type;
	tensor->n_dims = dims;
	tensor->ne[0] = ne0;
	tensor->ne[1] = ne1;
	tensor->data.resize(static_cast<std::size_t>(ne0 * ne1) * ggml_type_size(type));
	ggml_tensor * raw = tensor.get();
	ctx->tensors.push_back(std::move(tensor));
	return raw;
}

inline ggml_tensor * ggml_new_tensor_1d(ggml_context * ctx, ggml_type type, int64_t ne0) {
	return ggml_make_tensor(ctx, type, 1, ne0);
}

inline ggml_tensor * ggml_new_tensor_2d(ggml_context * ctx, ggml_type type, int64_t ne0, int64_t ne1) {
	return ggml_make_tensor(ctx, type, 2, ne0, ne1);
}

inline ggml_tensor * ggml_binary_op(ggml_context * ctx, ggml_tensor * a, ggml_tensor * b) {
	if (!ctx || !a || !b) return nullptr;
	ggml_tensor * tensor = ggml_make_tensor(ctx, a->type, a->n_dims, a->ne[0], a->ne[1]);
	tensor->src0 = a;
	tensor->src1 = b;
	return tensor;
}

inline ggml_tensor * ggml_add(ggml_context * ctx, ggml_tensor * a, ggml_tensor * b) {
	ggml_tensor * tensor = ggml_binary_op(ctx, a, b);
	if (tensor) tensor->op = ggml_tensor::Op::Add;
	return tensor;
}

inline ggml_tensor * ggml_mul(ggml_context * ctx, ggml_tensor * a, ggml_tensor * b) {
	ggml_tensor * tensor = ggml_binary_op(ctx, a, b);
	if (tensor) tensor->op = ggml_tensor::Op::Mul;
	return tensor;
}

inline ggml_tensor * ggml_mul_mat(ggml_context * ctx, ggml_tensor * a, ggml_tensor * b) {
	if (!ctx || !a || !b) return nullptr;
	ggml_tensor * tensor = ggml_make_tensor(ctx, a->type, 2, b->ne[1], a->ne[1]);
	tensor->op = ggml_tensor::Op::MatMul;
	tensor->src0 = a;
	tensor->src1 = b;
	return tensor;
}

inline int ggml_n_dims(const ggml_tensor * tensor) {
	return tensor ? tensor->n_dims : 0;
}

inline int64_t ggml_nelements(const ggml_tensor * tensor) {
	if (!tensor) return 0;
	int64_t total = 1;
	for (int i = 0; i < tensor->n_dims; ++i) {
		total *= tensor->ne[i];
	}
	return total;
}

inline std::size_t ggml_nbytes(const ggml_tensor * tensor) {
	return tensor ? static_cast<std::size_t>(ggml_nelements(tensor)) * ggml_type_size(tensor->type) : 0;
}

inline ggml_cgraph * ggml_new_graph(ggml_context * ctx) {
	if (!ctx) return nullptr;
	auto graph = std::make_unique<ggml_cgraph>();
	ggml_cgraph * raw = graph.get();
	ctx->graphs.push_back(std::move(graph));
	return raw;
}

inline void ggml_build_forward_expand(ggml_cgraph * graph, ggml_tensor * tensor) {
	if (graph && tensor) {
		graph->nodes.push_back(tensor);
	}
}

inline int ggml_graph_n_nodes(const ggml_cgraph * graph) {
	return graph ? static_cast<int>(graph->nodes.size()) : 0;
}

inline void ggml_compute_tensor(ggml_tensor * tensor) {
	if (!tensor || !tensor->src0 || !tensor->src1 || tensor->type != GGML_TYPE_F32) {
		return;
	}

	const std::size_t count = static_cast<std::size_t>(ggml_nelements(tensor));
	const auto * a = reinterpret_cast<const float *>(tensor->src0->data.data());
	const auto * b = reinterpret_cast<const float *>(tensor->src1->data.data());
	auto * out = reinterpret_cast<float *>(tensor->data.data());

	switch (tensor->op) {
	case ggml_tensor::Op::Add:
		for (std::size_t i = 0; i < count; ++i) out[i] = a[i] + b[i];
		break;
	case ggml_tensor::Op::Mul:
		for (std::size_t i = 0; i < count; ++i) out[i] = a[i] * b[i];
		break;
	case ggml_tensor::Op::MatMul:
	case ggml_tensor::Op::None:
		break;
	}
}
