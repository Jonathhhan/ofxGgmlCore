cmake_minimum_required(VERSION 3.18)
project(ofxGgml_rewrite_tests CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

add_executable(ofxGgml_rewrite_tests
	test_main.cpp
	test_result.cpp
	test_public_headers.cpp
	test_tensor.cpp
	test_graph.cpp
	test_runtime.cpp
	test_model.cpp
	test_text.cpp
	test_embedding.cpp
	test_llama_cli_text.cpp
	test_llama_server_text.cpp
	test_segmentation.cpp
	../src/core/ofxGgmlRuntime.cpp
	../src/compute/ofxGgmlTensor.cpp
	../src/compute/ofxGgmlGraph.cpp
	../src/model/ofxGgmlModel.cpp
	../src/inference/ofxGgmlEmbedding.cpp
	../src/inference/ofxGgmlLlamaServerEmbeddingBackend.cpp
	../src/inference/ofxGgmlTextGeneration.cpp
	../src/inference/ofxGgmlLlamaCliTextBackend.cpp
	../src/inference/ofxGgmlLlamaServerTextBackend.cpp
	../src/inference/ofxGgmlSegmentationInference.cpp)

target_include_directories(ofxGgml_rewrite_tests PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}
	${CMAKE_CURRENT_SOURCE_DIR}/../src)

add_library(ofxGgml_public_header_includes OBJECT
	public_headers/include_ofxGgml.cpp
	public_headers/include_ofxGgmlCore.cpp
	public_headers/include_ofxGgmlEmbedding.cpp
	public_headers/include_ofxGgmlLlamaServerEmbeddingBackend.cpp
	public_headers/include_ofxGgmlSam3.cpp
	public_headers/include_ofxGgmlSegmentation.cpp
	public_headers/include_ofxGgmlText.cpp)

target_include_directories(ofxGgml_public_header_includes PRIVATE
	${CMAKE_CURRENT_SOURCE_DIR}
	${CMAKE_CURRENT_SOURCE_DIR}/../src)

enable_testing()
add_test(NAME ofxGgml_rewrite_tests COMMAND ofxGgml_rewrite_tests)
