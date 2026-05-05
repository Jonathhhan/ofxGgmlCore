#include "ofApp.h"

namespace {
constexpr const char * kSeedPreset = R"milkdrop([preset00]
per_frame_1=wave_r = 0.5 + 0.5*sin(time*1.7)
per_frame_2=wave_g = 0.5 + 0.5*sin(time*2.1)
per_frame_3=zoom = 1.01 + 0.02*bass
per_pixel_1=rot = rot + 0.01*sin(rad*6 + time)
)milkdrop";
}

void ofApp::setup() {
ofSetWindowTitle("ofxGgml - Visualization Companion Example");
ofBackground(10, 12, 18);
request.prompt = "neon ocean tunnel with slow bass-reactive pulses";
request.category = "Abstract / tunnel";
request.randomness = 0.55f;
request.audioReactive = true;
request.seamlessLoop = true;
request.existingPresetText = kSeedPreset;
presetText = kSeedPreset;
rebuildPreview();
}

void ofApp::rebuildPreview() {
validation = ofxGgmlMilkDropGenerator::validatePreset(presetText);
lines.clear();
lines.push_back("Extracted from the removed GUI MilkDrop panel into a focused VJ/visualization example.");
lines.push_back("Demonstrates prompt preparation, preset sanitization, validation, repair/generation hooks, and saving.");
lines.push_back("");
lines.push_back("Prompt: " + request.prompt);
lines.push_back("Category: " + request.category);
lines.push_back(std::string("Audio reactive: ") + (request.audioReactive ? "yes" : "no"));
lines.push_back(std::string("Seamless loop: ") + (request.seamlessLoop ? "yes" : "no"));
lines.push_back("");

const auto prepared = generator.preparePrompt(request);
lines.push_back("Prepared label: " + prepared.label);
lines.push_back("Prepared prompt preview: " + prepared.prompt.substr(0, 180) + "...");
lines.push_back("");
lines.push_back(std::string("Validation: ") + (validation.valid ? "valid" : "needs attention"));
lines.push_back("Assignments: " + ofToString(validation.assignmentCount));
for (const auto & issue : validation.issues) {
lines.push_back(issue.severity + " line " + ofToString(issue.line) + ": " + issue.message);
}
lines.push_back("");
lines.push_back("Press G to generate with a configured modelPath, S to save sanitized preset, V to revalidate.");
status = "Preview ready. Add ofxProjectM separately if you want live preset playback.";
}

void ofApp::generatePreset() {
if (modelPath.empty()) {
status = "Set modelPath in source before generating a new preset.";
return;
}
const auto result = generator.generatePreset(modelPath, request);
if (!result.success) {
status = "Generation failed: " + result.error;
return;
}
presetText = result.presetText;
status = "Generated preset with " + ofToString(result.validation.assignmentCount) + " assignments.";
rebuildPreview();
}

void ofApp::savePreset() {
const auto sanitized = ofxGgmlMilkDropGenerator::sanitizePresetText(presetText);
const auto filename = ofxGgmlMilkDropGenerator::makeSuggestedFileName(request.prompt, request.category);
const auto path = ofToDataPath("generated/milkdrop/" + filename, true);
const auto savedPath = generator.savePreset(sanitized, path);
status = savedPath.empty() ? "Save failed." : "Saved " + savedPath;
}

void ofApp::draw() {
ofBackgroundGradient(ofColor(20, 12, 28), ofColor(4, 6, 12), OF_GRADIENT_CIRCULAR);
ofSetColor(245);
ofDrawBitmapStringHighlight("ofxGgml Visualization Example", 28, 30);
float y = 68;
ofSetColor(220);
for (const auto & line : lines) {
ofDrawBitmapString(line, 28, y);
y += 18;
}
ofSetColor(180, 255, 180);
ofDrawBitmapString(status, 28, ofGetHeight() - 34);
}

void ofApp::keyPressed(int key) {
if (key == 'g' || key == 'G') generatePreset();
if (key == 's' || key == 'S') savePreset();
if (key == 'v' || key == 'V') rebuildPreview();
}
