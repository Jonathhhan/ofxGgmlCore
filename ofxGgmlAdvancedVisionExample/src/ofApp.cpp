#include "ofApp.h"

#include <algorithm>
#include <cmath>
#include <functional>

namespace {
std::vector<float> makeEmbedding(const std::string & seed) {
std::vector<float> values(8, 0.0f);
for (size_t i = 0; i < values.size(); ++i) {
const auto hash = std::hash<std::string>{}(seed + ofToString(i));
values[i] = static_cast<float>((hash % 2000) - 1000) / 1000.0f;
}
float norm = 0.0f;
for (float value : values) norm += value * value;
norm = std::sqrt(std::max(norm, 0.0001f));
for (float & value : values) value /= norm;
return values;
}
}

void ofApp::setup() {
ofSetWindowTitle("ofxGgml - Advanced Vision Companion Example");
ofBackground(12, 15, 18);
candidateImages = {
ofToDataPath("images/reference_city.jpg", true),
ofToDataPath("images/reference_ocean.jpg", true),
ofToDataPath("images/reference_stage.jpg", true)
};
configureMockBackends();
rebuildPreview();
}

void ofApp::configureMockBackends() {
clip.setBackend(ofxGgmlClipInference::createClipBridgeBackend(
[](const ofxGgmlClipEmbeddingRequest & request) {
ofxGgmlClipEmbeddingResult result;
result.success = true;
result.backendName = "deterministic-example-clip";
result.inputId = request.inputId;
result.label = request.label;
result.text = request.text;
result.imagePath = request.imagePath;
result.modality = request.modality;
result.embedding = makeEmbedding(request.text.empty() ? request.imagePath : request.text);
return result;
}));
imageSearch.setClipInference(&clip);

diffusion.setBackend(ofxGgmlDiffusionInference::createStableDiffusionBridgeBackend(
[](const ofxGgmlImageGenerationRequest & request) {
ofxGgmlImageGenerationResult result;
result.success = true;
result.backendName = "example-diffusion-bridge";
ofxGgmlGeneratedImage image;
image.path = ofFilePath::join(request.outputDir.empty() ? "generated" : request.outputDir, request.outputPrefix + "_0001.png");
image.width = request.width;
image.height = request.height;
image.seed = request.seed;
image.selected = true;
result.images.push_back(image);
return result;
}));
}

void ofApp::rebuildPreview() {
lines.clear();
lines.push_back("Extracted from removed Diffusion/CLIP and ImageSearch GUI panels into one focused vision example.");
lines.push_back("Demonstrates bridge boundaries without requiring ofxStableDiffusion or network search at launch.");
lines.push_back("");
lines.push_back("Press C: rank local candidate images with CLIP-style embeddings.");
lines.push_back("Press D: validate and dispatch a diffusion bridge request.");
lines.push_back("Press W: query Wikimedia Commons image search (network optional).");
lines.push_back("Use ofxGgmlSamExample for interactive point-prompt segmentation.");
status = "Mock bridge backends configured.";
}

void ofApp::runImageSearch() {
ofxGgmlImageSearchRequest request;
request.prompt = "openFrameworks creative coding installation";
request.maxResults = 3;
request.useSemanticRanking = false;
const auto result = imageSearch.search(request);
lines.push_back("");
lines.push_back(std::string("Image search: ") + (result.success ? "success" : "failed"));
if (!result.error.empty()) lines.push_back("Error: " + result.error);
for (const auto & item : result.items) {
lines.push_back("- " + item.title + " <" + item.pageUrl + ">");
}
status = "Image search complete.";
}

void ofApp::runRanking() {
ofxGgmlClipImageRankingRequest request;
request.prompt = "cinematic neon ocean tunnel";
request.imagePaths = candidateImages;
request.topK = 3;
const auto result = clip.rankImagesForText(request);
lines.push_back("");
lines.push_back(std::string("CLIP ranking: ") + (result.success ? "success" : "failed"));
for (const auto & hit : result.hits) {
lines.push_back(ofToString(hit.score, 3) + "  " + hit.imagePath);
}
status = "Ranking complete.";
}

void ofApp::runDiffusionValidation() {
ofxGgmlImageGenerationRequest request;
request.prompt = "cinematic neon ocean tunnel, audiovisual installation still";
request.outputDir = ofToDataPath("generated/vision", true);
request.outputPrefix = "advanced_vision";
request.width = 512;
request.height = 512;
request.steps = 12;
request.selectionMode = ofxGgmlImageSelectionMode::BestOnly;
const auto validation = ofxGgmlDiffusionInference::validateRequest(request, diffusion.getCapabilities());
const auto result = diffusion.generate(request);
lines.push_back("");
lines.push_back(std::string("Diffusion validation: ") + (validation.valid ? "valid" : validation.error));
lines.push_back(std::string("Diffusion bridge: ") + (result.success ? "success" : "failed"));
for (const auto & image : result.images) lines.push_back("Generated: " + image.path);
status = "Diffusion bridge request complete.";
}

void ofApp::draw() {
ofBackgroundGradient(ofColor(12, 20, 24), ofColor(6, 8, 10), OF_GRADIENT_CIRCULAR);
ofSetColor(245);
ofDrawBitmapStringHighlight("ofxGgml Advanced Vision Example", 28, 30);
float y = 68;
ofSetColor(220);
for (const auto & line : lines) {
ofDrawBitmapString(line, 28, y);
y += 18;
}
ofSetColor(120, 220, 255);
ofDrawBitmapString(status, 28, ofGetHeight() - 34);
}

void ofApp::keyPressed(int key) {
if (key == 'w' || key == 'W') runImageSearch();
if (key == 'c' || key == 'C') runRanking();
if (key == 'd' || key == 'D') runDiffusionValidation();
}
