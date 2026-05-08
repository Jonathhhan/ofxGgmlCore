#pragma once

#include "ofxGgmlTensor.h"

#include <cstddef>
#include <cstdint>
#include <vector>

struct ggml_context;
struct ggml_cgraph;

class ofxGgmlGraph {
public:
	explicit ofxGgmlGraph(std::size_t memoryBytes = 16u * 1024u * 1024u);
	~ofxGgmlGraph();

	ofxGgmlGraph(const ofxGgmlGraph &) = delete;
	ofxGgmlGraph & operator=(const ofxGgmlGraph &) = delete;
	ofxGgmlGraph(ofxGgmlGraph && other) noexcept;
	ofxGgmlGraph & operator=(ofxGgmlGraph && other) noexcept;

	ofxGgmlTensor tensor1d(ofxGgmlType type, int64_t ne0);
	ofxGgmlTensor tensor2d(ofxGgmlType type, int64_t ne0, int64_t ne1);

	ofxGgmlTensor add(ofxGgmlTensor a, ofxGgmlTensor b);
	ofxGgmlTensor mul(ofxGgmlTensor a, ofxGgmlTensor b);
	ofxGgmlTensor matmul(ofxGgmlTensor a, ofxGgmlTensor b);

	void build(ofxGgmlTensor output);
	void build(const std::vector<ofxGgmlTensor> & outputs);
	bool isBuilt() const;
	int nodeCount() const;

	ggml_context * context() const;
	ggml_cgraph * raw() const;

private:
	void release();

	ggml_context * ctx = nullptr;
	ggml_cgraph * graph = nullptr;
	std::size_t memoryBytes = 0;
};
