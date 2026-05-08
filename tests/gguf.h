#pragma once

#include <cstdint>
#include <fstream>
#include <string>
#include <utility>
#include <vector>

struct gguf_context {
	uint64_t tensorCount = 0;
	uint64_t metadataCount = 0;
	std::vector<std::pair<std::string, std::string>> stringValues;
};

struct gguf_init_params {
	bool no_alloc = true;
	void * ctx = nullptr;
};

inline bool gguf_read_u32(std::istream & input, uint32_t & value) {
	input.read(reinterpret_cast<char *>(&value), sizeof(value));
	return input.good();
}

inline bool gguf_read_u64(std::istream & input, uint64_t & value) {
	input.read(reinterpret_cast<char *>(&value), sizeof(value));
	return input.good();
}

inline bool gguf_read_string(std::istream & input, std::string & value) {
	uint64_t size = 0;
	if (!gguf_read_u64(input, size)) return false;
	value.assign(static_cast<std::size_t>(size), '\0');
	if (size == 0) return true;
	input.read(value.data(), static_cast<std::streamsize>(size));
	return input.good();
}

inline gguf_context * gguf_init_from_file(const char * path, gguf_init_params) {
	if (!path) return nullptr;

	std::ifstream input(path, std::ios::binary);
	if (!input) return nullptr;

	char magic[4] = {};
	input.read(magic, sizeof(magic));
	if (!input.good() || magic[0] != 'G' || magic[1] != 'G' || magic[2] != 'U' || magic[3] != 'F') {
		return nullptr;
	}

	uint32_t version = 0;
	uint64_t tensorCount = 0;
	uint64_t metadataCount = 0;
	if (!gguf_read_u32(input, version) || !gguf_read_u64(input, tensorCount) || !gguf_read_u64(input, metadataCount)) {
		return nullptr;
	}
	if (version == 0) return nullptr;

	auto * context = new gguf_context();
	context->tensorCount = tensorCount;
	context->metadataCount = metadataCount;

	for (uint64_t i = 0; i < metadataCount; ++i) {
		std::string key;
		if (!gguf_read_string(input, key)) {
			delete context;
			return nullptr;
		}

		uint32_t valueType = 0;
		if (!gguf_read_u32(input, valueType)) {
			delete context;
			return nullptr;
		}

		constexpr uint32_t stringType = 8;
		if (valueType != stringType) {
			delete context;
			return nullptr;
		}

		std::string value;
		if (!gguf_read_string(input, value)) {
			delete context;
			return nullptr;
		}
		context->stringValues.push_back({ key, value });
	}

	return context;
}

inline void gguf_free(gguf_context * context) {
	delete context;
}

inline int64_t gguf_get_n_tensors(const gguf_context * context) {
	return context ? static_cast<int64_t>(context->tensorCount) : 0;
}

inline int64_t gguf_get_n_kv(const gguf_context * context) {
	return context ? static_cast<int64_t>(context->metadataCount) : 0;
}

inline int gguf_find_key(const gguf_context * context, const char * key) {
	if (!context || !key) return -1;
	for (std::size_t i = 0; i < context->stringValues.size(); ++i) {
		if (context->stringValues[i].first == key) {
			return static_cast<int>(i);
		}
	}
	return -1;
}

inline const char * gguf_get_val_str(const gguf_context * context, int keyIndex) {
	if (!context || keyIndex < 0 || static_cast<std::size_t>(keyIndex) >= context->stringValues.size()) {
		return nullptr;
	}
	return context->stringValues[static_cast<std::size_t>(keyIndex)].second.c_str();
}
