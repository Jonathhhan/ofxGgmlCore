#include "ofApp.h"

namespace {
constexpr float kMargin = 28.0f;
constexpr float kLineHeight = 18.0f;
}

void ofApp::setup() {
ofSetWindowTitle("ofxGgml - Video Essay Companion Example");
ofBackground(14, 16, 22);
ofSetFrameRate(60);

request.topic = "How local-first AI tools change creative research";
request.sourceUrls = {
"https://example.com/source-a",
"https://example.com/source-b"
};
request.maxCitations = 6;
request.targetDurationSeconds = 90.0;
request.tone = "clear, engaging, and grounded";
request.audience = "creative technologists";
request.includeCounterpoints = true;
request.inferenceSettings.maxTokens = 768;

rebuildPreview();
}

void ofApp::rebuildPreview() {
lines.clear();
lines.push_back("Extracted from the removed GUI VideoEssay panel into a focused companion example.");
lines.push_back("Pipeline: citations -> outline -> script -> voice cues -> SRT -> video/edit planning handoffs.");
lines.push_back("");
lines.push_back("Topic: " + request.topic);
lines.push_back("Tone: " + request.tone);
lines.push_back("Audience: " + request.audience);
lines.push_back("Sources: " + ofToString(request.sourceUrls.size()));
lines.push_back("");

const auto validation = ofxGgmlVideoEssayWorkflow::validateRequest(request);
lines.push_back(std::string("Validation: ") + (validation.ok ? "ready" : "needs setup"));
for (const auto & warning : validation.warnings) {
lines.push_back("Warning: " + warning);
}
for (const auto & error : validation.errors) {
lines.push_back("Error: " + error);
}

ofxGgmlVideoEssaySection intro;
intro.index = 1;
intro.title = "Opening question";
intro.narrationText = "What changes when creative research can happen locally, privately, and iteratively?";
intro.estimatedDurationSeconds = 8.0;

ofxGgmlVideoEssaySection body;
body.index = 2;
body.title = "Evidence and workflow";
body.narrationText = "A companion app can gather citations, draft an outline, and hand off structured scenes without owning rendering.";
body.estimatedDurationSeconds = 12.0;

auto cues = ofxGgmlVideoEssayWorkflow::buildVoiceCueSheet({ intro, body });
const auto srt = ofxGgmlVideoEssayWorkflow::buildSrt(cues);
lines.push_back("");
lines.push_back("Static SRT preview from extracted helper:");
lines.push_back(srt.substr(0, 160) + (srt.size() > 160 ? "..." : ""));
lines.push_back("");
lines.push_back("Press R to run the full workflow after setting request.modelPath in source.");
status = "Preview ready. Full generation is opt-in so the example opens without models.";
}

void ofApp::runWorkflow() {
if (request.modelPath.empty()) {
status = "Set request.modelPath in setup() before running full text generation.";
return;
}
status = "Running video essay workflow...";
const auto result = workflow.run(request);
appendResultSummary(result);
}

void ofApp::appendResultSummary(const ofxGgmlVideoEssayResult & result) {
lines.push_back("");
lines.push_back(std::string("Workflow result: ") + (result.success ? "success" : "failed"));
lines.push_back("Backend: " + result.backendName);
if (!result.error.empty()) {
lines.push_back("Error: " + result.error);
}
if (!result.outline.empty()) {
lines.push_back("Outline: " + result.outline.substr(0, 180));
}
if (!result.workflowManifestJson.empty()) {
lines.push_back("Manifest bytes: " + ofToString(result.workflowManifestJson.size()));
}
status = result.success ? "Workflow complete." : "Workflow failed; see messages.";
}

void ofApp::draw() {
ofBackgroundGradient(ofColor(18, 22, 30), ofColor(8, 10, 14), OF_GRADIENT_CIRCULAR);
ofSetColor(245);
ofDrawBitmapStringHighlight("ofxGgml Video Essay Example", kMargin, 30);
ofSetColor(210);
float y = 68.0f;
for (const auto & line : lines) {
ofDrawBitmapString(line, kMargin, y);
y += kLineHeight;
}
ofSetColor(120, 190, 255);
ofDrawBitmapString(status, kMargin, ofGetHeight() - 34.0f);
}

void ofApp::keyPressed(int key) {
if (key == 'r' || key == 'R') {
runWorkflow();
}
}
