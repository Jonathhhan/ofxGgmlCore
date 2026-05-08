#include "test_harness.h"
#include "../src/compute/ofxGgmlGraph.h"
#include "../src/compute/ofxGgmlTensor.h"

OFXGGML_TEST(default_tensor_is_invalid) {
	ofxGgmlTensor tensor;
	OFXGGML_REQUIRE(!tensor);
	OFXGGML_REQUIRE(!tensor.isValid());
	OFXGGML_REQUIRE(tensor.raw() == nullptr);
	OFXGGML_REQUIRE(tensor.dims() == 0);
	OFXGGML_REQUIRE(tensor.extent(0) == 0);
	OFXGGML_REQUIRE(tensor.bytes() == 0);
	OFXGGML_REQUIRE(tensor.elementCount() == 0);
}

OFXGGML_TEST(tensor_reports_shape_and_storage) {
	ofxGgmlGraph graph;
	ofxGgmlTensor tensor = graph.tensor2d(ofxGgmlType::F32, 4, 3);

	OFXGGML_REQUIRE(tensor);
	OFXGGML_REQUIRE(tensor.type() == ofxGgmlType::F32);
	OFXGGML_REQUIRE(tensor.dims() == 2);
	OFXGGML_REQUIRE(tensor.extent(0) == 4);
	OFXGGML_REQUIRE(tensor.extent(1) == 3);
	OFXGGML_REQUIRE(tensor.extent(4) == 0);
	OFXGGML_REQUIRE(tensor.elementCount() == 12);
	OFXGGML_REQUIRE(tensor.bytes() == 48);
}

OFXGGML_TEST(tensor_rejects_invalid_dimensions) {
	ofxGgmlGraph graph;

	OFXGGML_REQUIRE(!graph.tensor1d(ofxGgmlType::F32, 0));
	OFXGGML_REQUIRE(!graph.tensor1d(ofxGgmlType::F32, -1));
	OFXGGML_REQUIRE(!graph.tensor2d(ofxGgmlType::F32, 4, 0));
	OFXGGML_REQUIRE(!graph.tensor2d(ofxGgmlType::F32, 0, 4));
}
