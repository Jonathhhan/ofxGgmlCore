#pragma once

#include <cstdint>
#include <fstream>
#include <string>
#include <utility>
#include <vector>

enum gguf_type {
	GGUF_TYPE_UINT8 = 0,
	GGUF_TYPE_INT8 = 1,
	GGUF_TYPE_UINT16 = 2,
	GGUF_TYPE_INT16 = 3,
	GGUF_TYPE_UINT32 = 4,
	GGUF_TYPE_INT32 = 5,
	GGUF_TYPE_FLOAT32 = 6,
	GGUF_TYPE_BOOL = 7,
	GGUF_TYPE_STRING = 8,
	GGUF_TYPE_ARRAY = 9,
	GGUF_TYPE_UINT64 = 10,
	GGUF_TYPE_INT64 = 11,
	GGUF_TYPE_FLOAT64 = 12,
	GGUF_TYPE_COUNT,
};

struct gguf_value {
	std::string key;
	gguf_type type = GGUF_TYPE_STRING;
	std::string stringValue;
	uint64_t unsignedValue = 0;
	int64_t signedValue = 0;
};

struct gguf_context {
	uint64_t tensorCount = 0;
	uint64_t metadataCount = 0;
	std::vector<gguf_value> values;
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

		gguf_value value;
		value.key = key;
		value.type = static_cast<gguf_type>(valueType);
		if (value.type == GGUF_TYPE_STRING) {
			if (!gguf_read_string(input, value.stringValue)) {
				delete context;
				return nullptr;
			}
		} else if (value.type == GGUF_TYPE_UINT32) {
			uint32_t blockCount = 0;
			if (!gguf_read_u32(input, blockCount)) {
				delete context;
				return nullptr;
			}
			value.unsignedValue = blockCount;
		} else if (value.type == GGUF_TYPE_UINT64) {
			uint64_t blockCount = 0;
			if (!gguf_read_u64(input, blockCount)) {
				delete context;
				return nullptr;
			}
			value.unsignedValue = blockCount;
		} else {
			delete context;
			return nullptr;
		}
		context->values.push_back(value);
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
	for (std::size_t i = 0; i < context->values.size(); ++i) {
		if (context->values[i].key == key) {
			return static_cast<int>(i);
		}
	}
	return -1;
}

inline gguf_type gguf_get_kv_type(const gguf_context * context, int64_t keyIndex) {
	if (!context || keyIndex < 0 || static_cast<std::size_t>(keyIndex) >= context->values.size()) {
		return GGUF_TYPE_COUNT;
	}
	return context->values[static_cast<std::size_t>(keyIndex)].type;
}

inline uint8_t gguf_get_val_u8(const gguf_context * context, int64_t keyIndex) {
	return static_cast<uint8_t>(context->values[static_cast<std::size_t>(keyIndex)].unsignedValue);
}

inline int8_t gguf_get_val_i8(const gguf_context * context, int64_t keyIndex) {
	return static_cast<int8_t>(context->values[static_cast<std::size_t>(keyIndex)].signedValue);
}

inline uint16_t gguf_get_val_u16(const gguf_context * context, int64_t keyIndex) {
	return static_cast<uint16_t>(context->values[static_cast<std::size_t>(keyIndex)].unsignedValue);
}

inline int16_t gguf_get_val_i16(const gguf_context * context, int64_t keyIndex) {
	return static_cast<int16_t>(context->values[static_cast<std::size_t>(keyIndex)].signedValue);
}

inline uint32_t gguf_get_val_u32(const gguf_context * context, int64_t keyIndex) {
	return static_cast<uint32_t>(context->values[static_cast<std::size_t>(keyIndex)].unsignedValue);
}

inline int32_t gguf_get_val_i32(const gguf_context * context, int64_t keyIndex) {
	return static_cast<int32_t>(context->values[static_cast<std::size_t>(keyIndex)].signedValue);
}

inline uint64_t gguf_get_val_u64(const gguf_context * context, int64_t keyIndex) {
	return context->values[static_cast<std::size_t>(keyIndex)].unsignedValue;
}

inline int64_t gguf_get_val_i64(const gguf_context * context, int64_t keyIndex) {
	return context->values[static_cast<std::size_t>(keyIndex)].signedValue;
}

inline const char * gguf_get_val_str(const gguf_context * context, int keyIndex) {
	if (!context || keyIndex < 0 || static_cast<std::size_t>(keyIndex) >= context->values.size()) {
		return nullptr;
	}
	return context->values[static_cast<std::size_t>(keyIndex)].stringValue.c_str();
}
