#include "test_harness.h"
#include "../src/ofxGgmlEmbedding.h"

#include <memory>

OFXGGML_TEST(embedding_default_backend_exists) {
	ofxGgmlEmbeddingGenerator generator;

	OFXGGML_REQUIRE(generator.getBackend() != nullptr);
	OFXGGML_REQUIRE(!generator.getBackend()->getBackendName().empty());
}

OFXGGML_TEST(embedding_unconfigured_backend_reports_error) {
	ofxGgmlEmbeddingGenerator generator;
	const auto result = generator.embed("hello");

	OFXGGML_REQUIRE(!result);
	OFXGGML_REQUIRE(result.isError());
	OFXGGML_REQUIRE(!result.error.empty());
	OFXGGML_REQUIRE(result.backendName == "EmbeddingBridge");
}

OFXGGML_TEST(embedding_bridge_backend_runs_callback) {
	auto backend = std::dynamic_pointer_cast<ofxGgmlEmbeddingBridgeBackend>(
		ofxGgmlEmbeddingGenerator::createEmbeddingBridgeBackend());
	OFXGGML_REQUIRE(backend != nullptr);
	OFXGGML_REQUIRE(!backend->isConfigured());

	backend->setEmbedFunction(
		[](const ofxGgmlEmbeddingRequest & request) {
			ofxGgmlEmbeddingResult result;
			result.success = true;
			result.embedding = {
				static_cast<float>(request.input.size()),
				1.0f
			};
			result.embeddings.push_back(result.embedding);
			return result;
		});

	ofxGgmlEmbeddingGenerator generator;
	generator.setBackend(backend);
	const auto result = generator.embed("hello");

	OFXGGML_REQUIRE(result);
	OFXGGML_REQUIRE(result.isOk());
	OFXGGML_REQUIRE(!result.isError());
	OFXGGML_REQUIRE(result.backendName == "EmbeddingBridge");
	OFXGGML_REQUIRE(result.embedding.size() == 2);
	OFXGGML_REQUIRE(result.embedding[0] == 5.0f);
}

OFXGGML_TEST(embedding_utils_compute_cosine_similarity) {
	const std::vector<float> a = { 1.0f, 0.0f, 0.0f };
	const std::vector<float> b = { 0.0f, 1.0f, 0.0f };
	const std::vector<float> c = { 2.0f, 0.0f, 0.0f };

	OFXGGML_REQUIRE(ofxGgmlEmbeddingUtils::dotProduct(a, c) == 2.0f);
	OFXGGML_REQUIRE(ofxGgmlEmbeddingUtils::l2Norm(c) == 2.0f);
	OFXGGML_REQUIRE(ofxGgmlEmbeddingUtils::cosineSimilarity(a, b) == 0.0f);
	OFXGGML_REQUIRE(ofxGgmlEmbeddingUtils::cosineSimilarity(a, c) == 1.0f);
	OFXGGML_REQUIRE(ofxGgmlEmbeddingUtils::cosineSimilarity(a, {}) == 0.0f);
}
