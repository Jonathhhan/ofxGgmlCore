#include "test_harness.h"
#include "../src/compute/ofxGgmlGraph.h"

OFXGGML_TEST(graph_starts_unbuilt) {
	ofxGgmlGraph graph;

	OFXGGML_REQUIRE(graph.context() != nullptr);
	OFXGGML_REQUIRE(graph.raw() == nullptr);
	OFXGGML_REQUIRE(!graph.isBuilt());
	OFXGGML_REQUIRE(graph.nodeCount() == 0);
}

OFXGGML_TEST(graph_builds_single_output) {
	ofxGgmlGraph graph;
	ofxGgmlTensor a = graph.tensor1d(ofxGgmlType::F32, 4);
	ofxGgmlTensor b = graph.tensor1d(ofxGgmlType::F32, 4);
	ofxGgmlTensor sum = graph.add(a, b);

	graph.build(sum);

	OFXGGML_REQUIRE(sum);
	OFXGGML_REQUIRE(graph.raw() != nullptr);
	OFXGGML_REQUIRE(graph.isBuilt());
	OFXGGML_REQUIRE(graph.nodeCount() == 1);
}

OFXGGML_TEST(graph_builds_multiple_outputs) {
	ofxGgmlGraph graph;
	ofxGgmlTensor a = graph.tensor2d(ofxGgmlType::F32, 2, 2);
	ofxGgmlTensor b = graph.tensor2d(ofxGgmlType::F32, 2, 2);

	graph.build({ graph.add(a, b), graph.mul(a, b) });

	OFXGGML_REQUIRE(graph.isBuilt());
	OFXGGML_REQUIRE(graph.nodeCount() == 2);
}

OFXGGML_TEST(graph_rejects_invalid_build_outputs) {
	ofxGgmlGraph graph;

	graph.build(ofxGgmlTensor());
	OFXGGML_REQUIRE(!graph.isBuilt());
	OFXGGML_REQUIRE(graph.nodeCount() == 0);

	graph.build({});
	OFXGGML_REQUIRE(!graph.isBuilt());
	OFXGGML_REQUIRE(graph.nodeCount() == 0);
}

OFXGGML_TEST(graph_is_movable) {
	ofxGgmlGraph graph;
	ofxGgmlTensor tensor = graph.tensor1d(ofxGgmlType::F32, 8);
	ofxGgmlGraph moved(std::move(graph));

	moved.build(tensor);

	OFXGGML_REQUIRE(graph.context() == nullptr);
	OFXGGML_REQUIRE(moved.context() != nullptr);
	OFXGGML_REQUIRE(moved.isBuilt());
	OFXGGML_REQUIRE(moved.nodeCount() == 1);
}
