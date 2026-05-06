#include "ofApp.h"

#include <sstream>

namespace {
constexpr const char * kStarterAbc = R"abc(X:1
T:Night Tram Theme
M:4/4
L:1/8
Q:1/4=92
K:Cm
|: C2 G,2 C2 Eb2 | F2 G2 Bb2 G2 | Ab2 G2 F2 Eb2 | D2 F2 G4 :|
|: C4 Eb4 | G2 F2 Eb2 C2 | Ab4 G4 | F2 D2 C4 :|
)abc";

constexpr float kMargin = 28.0f;
constexpr float kLineHeight = 18.0f;

std::vector<std::string> wrapText(const std::string & text, size_t width) {
	std::vector<std::string> wrapped;
	std::istringstream input(text);
	std::string paragraph;
	while (std::getline(input, paragraph)) {
		std::istringstream words(paragraph);
		std::string word;
		std::string line;
		while (words >> word) {
			if (!line.empty() && line.size() + 1 + word.size() > width) {
				wrapped.push_back(line);
				line.clear();
			}
			if (!line.empty()) {
				line += " ";
			}
			line += word;
		}
		if (!line.empty()) {
			wrapped.push_back(line);
		}
	}
	return wrapped;
}
} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml - Music Example");
	ofBackground(12, 16, 22);
	ofSetFrameRate(60);

	promptRequest.sourceConcept =
		"A night tram crossing rain-lit streets, gentle momentum, hopeful final lift";
	promptRequest.style =
		"cinematic downtempo instrumental, warm analog synths, subtle orchestral texture";
	promptRequest.instrumentation =
		"felt piano, brushed drums, soft bass, glassy arpeggiated synth, low strings";
	promptRequest.mood = "intimate, nocturnal, reflective, quietly optimistic";
	promptRequest.targetDurationSeconds = 32;
	promptRequest.instrumentalOnly = true;

	notationRequest.sourceConcept = promptRequest.sourceConcept;
	notationRequest.title = "Night Tram Theme";
	notationRequest.style = "cinematic downtempo lead motif";
	notationRequest.key = "Cm";
	notationRequest.meter = "4/4";
	notationRequest.bars = 16;

	aceRequest.caption = promptRequest.sourceConcept + "; " + promptRequest.style;
	aceRequest.durationSeconds = 32.0f;
	aceRequest.instrumentalOnly = true;
	aceRequest.outputDir = ofToDataPath("generated/music", true);
	aceRequest.outputPrefix = "night-tram";

	abcSketch = kStarterAbc;
	generator.setCompletionExecutable(completionExecutable);
	aceStep.setServerUrl(aceStepServerUrl);
	rebuildPreview();
}

std::string ofApp::sharedAceStepModelDir() const {
	return ofFilePath::join(
		ofFilePath::join(
			ofFilePath::join(ofFilePath::getCurrentExeDir(), ".."),
			".."),
		"models/acestep/gguf");
}

void ofApp::appendWrapped(const std::string & label, const std::string & text, size_t width) {
	if (!label.empty()) {
		lines.push_back(label);
	}
	const auto wrapped = wrapText(text, width);
	if (wrapped.empty()) {
		lines.push_back("  (empty)");
		return;
	}
	for (const auto & line : wrapped) {
		lines.push_back("  " + line);
	}
}

void ofApp::rebuildPreview() {
	lines.clear();
	lines.push_back("Focused music companion example.");
	lines.push_back("Local path: prompt prep and ABC sketch validation work without any model.");
	lines.push_back("Rendered audio path: optional AceStep-compatible server.");
	lines.push_back("");
	lines.push_back("AceStep server: " + aceStepServerUrl);
	lines.push_back("AceStep GGUF model dir: " + sharedAceStepModelDir());
	lines.push_back("");
	appendWrapped("Concept:", promptRequest.sourceConcept);
	appendWrapped("Style:", promptRequest.style);
	lines.push_back("");

	const auto prepared = generator.prepareMusicPrompt(promptRequest);
	appendWrapped("Prepared prompt instruction preview:", prepared.prompt.substr(0, 320) + "...");
	lines.push_back("");

	const auto validation = ofxGgmlMusicGenerator::validateAbcNotation(abcSketch);
	lines.push_back(std::string("ABC sketch: ") + (validation.valid ? "valid" : "needs attention"));
	for (const auto & issue : validation.issues) {
		lines.push_back(issue.severity + ": " + issue.message);
	}
	lines.push_back("");
	lines.push_back("Keys: P prepare prompt, A save ABC, G generate with text model, H health, R render AceStep.");
	status = "Preview ready. Set textModelPath in source for model-backed prompt/ABC generation.";
}

void ofApp::preparePrompt() {
	const auto prepared = generator.prepareMusicPrompt(promptRequest);
	lines.push_back("");
	appendWrapped("Prepared music prompt request:", prepared.prompt, 118);
	status = "Prepared local music prompt request.";
}

void ofApp::saveAbcSketch() {
	const std::string outputPath = ofToDataPath(
		"generated/music/" + ofxGgmlMusicGenerator::makeSuggestedFileName(notationRequest.sourceConcept),
		true);
	const auto savedPath = ofxGgmlMusicGenerator::saveAbcNotation(abcSketch, outputPath);
	status = savedPath.empty()
		? "ABC save failed."
		: "Saved ABC sketch: " + savedPath;
}

void ofApp::generateWithTextModel() {
	if (textModelPath.empty()) {
		status = "Set textModelPath in src/ofApp.cpp before model-backed generation.";
		return;
	}

	ofxGgmlInferenceSettings settings;
	settings.maxTokens = 384;
	settings.temperature = 0.7f;

	const auto promptResult = generator.generateMusicPrompt(textModelPath, promptRequest, settings);
	if (!promptResult.success) {
		status = "Prompt generation failed: " + promptResult.error;
		return;
	}
	preparedPrompt = promptResult.musicPrompt;

	const auto abcResult = generator.generateAbcNotation(textModelPath, notationRequest, settings);
	if (abcResult.success) {
		abcSketch = abcResult.abcNotation;
	}

	lines.push_back("");
	appendWrapped("Generated music prompt:", preparedPrompt, 118);
	if (abcResult.success) {
		lines.push_back("Generated ABC notation validated.");
	} else {
		lines.push_back("ABC generation skipped/failed: " + abcResult.error);
	}
	status = "Text model generation complete.";
}

void ofApp::checkAceStep() {
	const auto health = aceStep.healthCheck(aceStepServerUrl);
	status = health.success
		? "AceStep server reachable: " + health.status
		: "AceStep health failed: " + health.error;
}

void ofApp::renderAceStep() {
	const auto health = aceStep.healthCheck(aceStepServerUrl);
	if (!health.success) {
		status = "AceStep server is not reachable: " + health.error;
		return;
	}

	aceRequest.caption = preparedPrompt.empty()
		? promptRequest.sourceConcept + "; " + promptRequest.style
		: ofxGgmlMusicGenerator::sanitizeMusicPrompt(preparedPrompt);
	const auto result = aceStep.generate(aceRequest, aceStepServerUrl);
	if (!result.success) {
		status = "AceStep render failed: " + result.error;
		return;
	}
	status = result.tracks.empty()
		? "AceStep render completed."
		: "Rendered: " + result.tracks.front().path;
}

void ofApp::draw() {
	ofBackgroundGradient(ofColor(18, 24, 32), ofColor(6, 8, 14), OF_GRADIENT_CIRCULAR);
	ofSetColor(245);
	ofDrawBitmapStringHighlight("ofxGgml Music Example", kMargin, 30);

	float y = 68.0f;
	ofSetColor(220);
	for (const auto & line : lines) {
		if (y > ofGetHeight() - 64.0f) {
			break;
		}
		ofDrawBitmapString(line, kMargin, y);
		y += line.empty() ? 10.0f : kLineHeight;
	}

	ofSetColor(160, 220, 255);
	ofDrawBitmapString(status, kMargin, ofGetHeight() - 34.0f);
}

void ofApp::keyPressed(int key) {
	if (key == 'p' || key == 'P') {
		preparePrompt();
	} else if (key == 'a' || key == 'A') {
		saveAbcSketch();
	} else if (key == 'g' || key == 'G') {
		generateWithTextModel();
	} else if (key == 'h' || key == 'H') {
		checkAceStep();
	} else if (key == 'r' || key == 'R') {
		renderAceStep();
	}
}
