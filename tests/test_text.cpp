#include "test_harness.h"
#include "../src/ofxGgmlText.h"

#include <atomic>
#include <memory>
#include <string>
#include <thread>

OFXGGML_TEST(text_default_backend_exists) {
	ofxGgmlTextGenerator generator;

	OFXGGML_REQUIRE(generator.getBackend() != nullptr);
	OFXGGML_REQUIRE(!generator.getBackend()->getBackendName().empty());
}

OFXGGML_TEST(text_unconfigured_backend_reports_error) {
	ofxGgmlTextGenerator generator;
	const auto result = generator.generate("hello", "model.gguf");

	OFXGGML_REQUIRE(!result);
	OFXGGML_REQUIRE(result.isError());
	OFXGGML_REQUIRE(!result.error.empty());
	OFXGGML_REQUIRE(result.backendName == "TextBridge");
}

OFXGGML_TEST(text_bridge_backend_runs_callback) {
	auto backend = std::dynamic_pointer_cast<ofxGgmlTextBridgeBackend>(
		ofxGgmlTextGenerator::createTextBridgeBackend());
	OFXGGML_REQUIRE(backend != nullptr);
	OFXGGML_REQUIRE(!backend->isConfigured());

	backend->setGenerateFunction(
		[](const ofxGgmlTextRequest & request,
			const ofxGgmlTextChunkCallback & onChunk) {
			ofxGgmlTextResult result;
			result.success = true;
			result.text = "echo: " + request.prompt;
			result.tokensGenerated = 2;
			if (onChunk) {
				OFXGGML_REQUIRE(onChunk("echo: "));
				OFXGGML_REQUIRE(onChunk(request.prompt));
			}
			result.metadata.push_back({ "model", request.modelPath });
			return result;
		});
	OFXGGML_REQUIRE(backend->isConfigured());

	std::string streamed;
	ofxGgmlTextGenerator generator;
	generator.setBackend(backend);
	const auto result = generator.generate(
		"hello",
		"model.gguf",
		{},
		[&](const std::string & chunk) {
			streamed += chunk;
			return true;
		});

	OFXGGML_REQUIRE(result);
	OFXGGML_REQUIRE(result.isOk());
	OFXGGML_REQUIRE(!result.isError());
	OFXGGML_REQUIRE(result.backendName == "TextBridge");
	OFXGGML_REQUIRE(result.text == "echo: hello");
	OFXGGML_REQUIRE(streamed == "echo: hello");
	OFXGGML_REQUIRE(result.tokensGenerated == 2);
	OFXGGML_REQUIRE(result.metadata.front().second == "model.gguf");
}

OFXGGML_TEST(text_set_null_backend_resets_to_bridge) {
	ofxGgmlTextGenerator generator;
	generator.setBackend(nullptr);

	OFXGGML_REQUIRE(generator.getBackend() != nullptr);
	OFXGGML_REQUIRE(generator.getBackend()->getBackendName() == "TextBridge");
}

OFXGGML_TEST(text_concurrent_backend_swap_is_thread_safe) {
	auto makeBackend = [](const std::string & value) {
		auto backend = std::dynamic_pointer_cast<ofxGgmlTextBridgeBackend>(
			ofxGgmlTextGenerator::createTextBridgeBackend());
		OFXGGML_REQUIRE(backend != nullptr);
		backend->setGenerateFunction(
			[value](const ofxGgmlTextRequest & request,
				const ofxGgmlTextChunkCallback &) {
				ofxGgmlTextResult result;
				result.success = true;
				result.text = value + ":" + request.prompt;
				return result;
			});
		return backend;
	};

	ofxGgmlTextGenerator generator;
	auto firstBackend = makeBackend("A");
	auto secondBackend = makeBackend("B");
	generator.setBackend(firstBackend);

	std::atomic<bool> failed{false};
	std::thread worker([&] {
		for (int i = 0; i < 500; ++i) {
			const auto result = generator.generate("hello", "model.gguf");
			if (!result || result.text.empty()) {
				failed.store(true);
				break;
			}
		}
	});

	for (int i = 0; i < 500; ++i) {
		generator.setBackend((i % 2 == 0) ? firstBackend : secondBackend);
	}
	worker.join();
	OFXGGML_REQUIRE(!failed.load());
}
