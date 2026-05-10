#include "test_harness.h"
#include "../src/compute/ofxGgmlGraph.h"
#include "../src/compute/ofxGgmlTensor.h"

OFXGGML_TEST(default_tensor_is_invalid) {
	ofxGgmlTensor tensor;
	OFXGGML_REQUIRE(!tensor);
	OFXGGML_REQUIRE(!tensor.isValid());
	OFXGGML_REQUIRE(tensor.raw() == nullptr);
	OFXGGML_REQUIRE(tensor.getNumDims() == 0);
	OFXGGML_REQUIRE(tensor.getExtent(0) == 0);
	OFXGGML_REQUIRE(tensor.getByteSize() == 0);
	OFXGGML_REQUIRE(tensor.getElementCount() == 0);
}

OFXGGML_TEST(tensor_reports_shape_and_storage) {
	ofxGgmlGraph graph;
	ofxGgmlTensor tensor = graph.tensor2d(ofxGgmlType::F32, 4, 3);

	OFXGGML_REQUIRE(tensor);
	OFXGGML_REQUIRE(tensor.getType() == ofxGgmlType::F32);
	OFXGGML_REQUIRE(tensor.getNumDims() == 2);
	OFXGGML_REQUIRE(tensor.getExtent(0) == 4);
	OFXGGML_REQUIRE(tensor.getExtent(1) == 3);
	OFXGGML_REQUIRE(tensor.getExtent(4) == 0);
	OFXGGML_REQUIRE(tensor.getElementCount() == 12);
	OFXGGML_REQUIRE(tensor.getByteSize() == 48);
}

OFXGGML_TEST(tensor_maps_public_type_to_ggml_type) {
	ofxGgmlGraph graph;
	ofxGgmlTensor tensor = graph.tensor1d(ofxGgmlType::I32, 5);

	OFXGGML_REQUIRE(tensor);
	OFXGGML_REQUIRE(tensor.getType() == ofxGgmlType::I32);
	OFXGGML_REQUIRE(tensor.getElementCount() == 5);
	OFXGGML_REQUIRE(tensor.getByteSize() == 20);
}

OFXGGML_TEST(tensor_rejects_invalid_dimensions) {
	ofxGgmlGraph graph;

	OFXGGML_REQUIRE(!graph.tensor1d(ofxGgmlType::F32, 0));
	OFXGGML_REQUIRE(!graph.tensor1d(ofxGgmlType::F32, -1));
	OFXGGML_REQUIRE(!graph.tensor2d(ofxGgmlType::F32, 4, 0));
	OFXGGML_REQUIRE(!graph.tensor2d(ofxGgmlType::F32, 0, 4));
}
