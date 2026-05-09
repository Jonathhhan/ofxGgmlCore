#include "ofxGgmlLlamaCliTextBackend.h"

#include <chrono>
#include <sstream>
#include <utility>

namespace {

void appendOption(std::vector<std::string> & args, const std::string & name, int value) {
	args.push_back(name);
	args.push_back(std::to_string(value));
}

void appendOption(std::vector<std::string> & args, const std::string & name, float value) {
	std::ostringstream stream;
	stream << value;
	args.push_back(name);
	args.push_back(stream.str());
}

std::string roleLabel(ofxGgmlTextRole role) {
	switch (role) {
	case ofxGgmlTextRole::System: return "System";
	case ofxGgmlTextRole::User: return "User";
	case ofxGgmlTextRole::Assistant: return "Assistant";
	}
	return "User";
}

} // namespace

ofxGgmlLlamaCliTextBackend::ofxGgmlLlamaCliTextBackend(
	ofxGgmlTextCommandRunner runner,
	std::string displayName)
	: m_runner(std::move(runner))
	, m_displayName(std::move(displayName)) {
}

void ofxGgmlLlamaCliTextBackend::setCommandRunner(
	ofxGgmlTextCommandRunner runner) {
	m_runner = std::move(runner);
}

bool ofxGgmlLlamaCliTextBackend::hasCommandRunner() const {
	return static_cast<bool>(m_runner);
}

std::string ofxGgmlLlamaCliTextBackend::backendName() const {
	return m_displayName.empty() ? "llama.cpp CLI" : m_displayName;
}

ofxGgmlTextResult ofxGgmlLlamaCliTextBackend::generate(
	const ofxGgmlTextRequest & request,
	ofxGgmlTextChunkCallback onChunk) const {
	ofxGgmlTextResult result;
	result.backendName = backendName();

	const std::string prompt = composePrompt(request);
	if (request.settings.executablePath.empty()) {
		result.error = "llama.cpp CLI executable path is empty";
		return result;
	}
	if (request.modelPath.empty()) {
		result.error = "model path is empty";
		return result;
	}
	if (prompt.empty()) {
		result.error = "prompt is empty";
		return result;
	}
	if (!m_runner) {
		result.error =
			"llama.cpp CLI command runner is not configured. Attach a process "
			"runner before calling generate().";
		return result;
	}

	const auto started = std::chrono::steady_clock::now();
	const ofxGgmlTextCommand command = buildCommand(request, prompt);
	const ofxGgmlTextCommandResult commandResult = m_runner(command, onChunk);
	result.elapsedMs = std::chrono::duration<float, std::milli>(
		std::chrono::steady_clock::now() - started).count();
	result.rawOutput = commandResult.output;
	result.metadata.push_back({ "executable", command.executablePath });
	result.metadata.push_back({ "model", request.modelPath });

	if (!commandResult.started) {
		result.error = commandResult.error.empty()
			? "llama.cpp CLI process did not start"
			: commandResult.error;
		return result;
	}
	if (commandResult.exitCode != 0) {
		result.error = commandResult.error.empty()
			? "llama.cpp CLI exited with code " + std::to_string(commandResult.exitCode)
			: commandResult.error;
		return result;
	}
	if (commandResult.output.empty()) {
		result.error = "llama.cpp CLI returned empty output";
		return result;
	}

	result.success = true;
	result.text = commandResult.output;
	result.finishReason = "stop";
	return result;
}

std::string ofxGgmlLlamaCliTextBackend::composePrompt(
	const ofxGgmlTextRequest & request) {
	if (!request.prompt.empty()) {
		return request.prompt;
	}

	std::ostringstream prompt;
	if (!request.systemPrompt.empty()) {
		prompt << "System: " << request.systemPrompt << "\n";
	}
	for (const auto & message : request.messages) {
		if (message.content.empty()) {
			continue;
		}
		prompt << roleLabel(message.role) << ": " << message.content << "\n";
	}
	return prompt.str();
}

ofxGgmlTextCommand ofxGgmlLlamaCliTextBackend::buildCommand(
	const ofxGgmlTextRequest & request,
	const std::string & prompt) {
	ofxGgmlTextCommand command;
	command.executablePath = request.settings.executablePath;
	command.inputText = prompt;

	auto & args = command.arguments;
	args.reserve(36 + request.settings.stopSequences.size() * 2);
	args.push_back("-m");
	args.push_back(request.modelPath);
	args.push_back("-p");
	args.push_back(prompt);
	appendOption(args, "-n", request.settings.maxTokens);
	appendOption(args, "--temp", request.settings.temperature);
	appendOption(args, "--top-p", request.settings.topP);
	appendOption(args, "--top-k", request.settings.topK);
	appendOption(args, "--repeat-penalty", request.settings.repeatPenalty);
	appendOption(args, "-c", request.settings.contextSize);
	appendOption(args, "-b", request.settings.batchSize);
	if (request.settings.gpuLayers >= 0) {
		appendOption(args, "-ngl", request.settings.gpuLayers);
	}
	if (request.settings.threads > 0) {
		appendOption(args, "-t", request.settings.threads);
	}
	if (request.settings.seed >= 0) {
		appendOption(args, "--seed", request.settings.seed);
	}
	for (const auto & stop : request.settings.stopSequences) {
		if (!stop.empty()) {
			args.push_back("--reverse-prompt");
			args.push_back(stop);
		}
	}
	args.push_back("--no-display-prompt");
	return command;
}
