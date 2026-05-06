#include "ofApp.h"

#include <algorithm>
#include <cmath>
#include <thread>

namespace {
constexpr float kMargin = 28.0f;
constexpr float kHeaderY = 30.0f;
constexpr float kHelpY = 58.0f;
constexpr float kLogLineHeight = 17.0f;
constexpr int kFallbackImageWidth = 960;
constexpr int kFallbackImageHeight = 540;

std::string defaultModelPath() {
	return ofToDataPath("models/sam/ggml-model-f16.bin", true);
}

std::string defaultImagePath() {
	return ofToDataPath("images/sam-input.png", true);
}

unsigned char maskValueAt(
	const ofxGgmlSegmentationMask & mask,
	int x,
	int y) {
	if (x < 0 || y < 0 || x >= mask.width || y >= mask.height) {
		return 0;
	}
	const size_t index = static_cast<size_t>(y) *
		static_cast<size_t>(mask.width) +
		static_cast<size_t>(x);
	return index < mask.pixels.size() ? mask.pixels[index] : 0;
}
} // namespace

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml SAM Example");
	ofSetFrameRate(60);
	ofBackground(12, 14, 18);
	modelPath = defaultModelPath();
	loadDefaultImage();
	configureSegmentationBackend();
	appendStatus("Ready. Click the image to move the point prompt, then press S.");
}

void ofApp::update() {
	updateImageLayout();
}

void ofApp::configureSegmentationBackend() {
	usingPreviewBackend = true;
	backendName = "preview segmentation";

#if OFXGGML_HAS_SAMCPP
	if (ofFile::doesFileExist(modelPath)) {
		ofxGgmlSamCppAdapters::RuntimeOptions options;
		options.threads = std::max(1u, std::thread::hardware_concurrency());
		segmentation.setBackend(
			ofxGgmlSamCppAdapters::createBackend(modelPath, options));
		usingPreviewBackend = false;
		backendName = "sam.cpp";
		appendStatus("sam.cpp backend attached: " + modelPath);
		return;
	}
	appendStatus("sam.cpp headers found, but model is missing: " + modelPath);
#else
	appendStatus("sam.cpp headers not found. Using preview backend.");
#endif

	segmentation.setBackend(
		ofxGgmlSegmentationInference::createSamCppBridgeBackend(
			[this](const ofxGgmlSegmentationRequest & request) {
				return runPreviewSegmentation(request);
			},
			"preview segmentation"));
}

void ofApp::loadDefaultImage() {
	if (!loadImage(defaultImagePath())) {
		createFallbackImage();
	}
	updateImageLayout();
}

bool ofApp::loadImage(const std::string & path) {
	ofImage loaded;
	if (!loaded.load(path)) {
		return false;
	}
	loaded.setImageType(OF_IMAGE_COLOR);
	sourceImage = loaded;
	imagePath = path;
	clearMask();
	appendStatus("Loaded image: " + imagePath);
	return true;
}

void ofApp::createFallbackImage() {
	ofPixels pixels;
	pixels.allocate(kFallbackImageWidth, kFallbackImageHeight, OF_PIXELS_RGB);
	for (int y = 0; y < kFallbackImageHeight; ++y) {
		for (int x = 0; x < kFallbackImageWidth; ++x) {
			const float nx = static_cast<float>(x) / static_cast<float>(kFallbackImageWidth);
			const float ny = static_cast<float>(y) / static_cast<float>(kFallbackImageHeight);
			const bool inSubject =
				std::pow((nx - 0.52f) / 0.22f, 2.0f) +
				std::pow((ny - 0.48f) / 0.32f, 2.0f) < 1.0f;
			ofColor color;
			if (inSubject) {
				color.setHsb(
					static_cast<unsigned char>(145 + 40 * ny),
					190,
					static_cast<unsigned char>(150 + 60 * nx));
			} else {
				color.setHsb(
					static_cast<unsigned char>(25 + 60 * nx),
					80,
					static_cast<unsigned char>(45 + 50 * ny));
			}
			pixels.setColor(x, y, color);
		}
	}
	sourceImage.setFromPixels(pixels);
	imagePath = "generated fallback image";
	clearMask();
	appendStatus("Using generated fallback image. Drop an image file to replace it.");
}

void ofApp::updateImageLayout() {
	if (!sourceImage.isAllocated()) {
		imageRect.set(0, 0, 0, 0);
		return;
	}
	const float availableW = std::max(100.0f, ofGetWidth() - 2.0f * kMargin);
	const float availableH = std::max(100.0f, ofGetHeight() - 180.0f);
	const float scale = std::min(
		availableW / sourceImage.getWidth(),
		availableH / sourceImage.getHeight());
	const float w = sourceImage.getWidth() * scale;
	const float h = sourceImage.getHeight() * scale;
	imageRect.set(
		kMargin + (availableW - w) * 0.5f,
		112.0f,
		w,
		h);
}

void ofApp::runSegmentation() {
	if (!sourceImage.isAllocated()) {
		appendStatus("No image loaded.");
		return;
	}
	if (!hasPromptPoint) {
		appendStatus("Click the image before running segmentation.");
		return;
	}

	ofxGgmlSegmentationRequest request;
	request.imagePath = imagePath;
	request.modelPath = modelPath;
	request.imageWidth = sourceImage.getWidth();
	request.imageHeight = sourceImage.getHeight();
	request.imageRgb = makeRgbBuffer();
	request.points.push_back({promptPoint.x, promptPoint.y, true});
	request.returnMultipleMasks = true;

	appendStatus("Running " + backendName + " at point " +
		ofToString(promptPoint.x, 3) + ", " + ofToString(promptPoint.y, 3) + "...");
	const auto result = segmentation.segment(request);
	rebuildMaskOverlay(result);

	if (result.success) {
		appendStatus("Segmentation produced " + ofToString(result.masks.size()) +
			" mask(s) in " + ofToString(result.elapsedMs, 1) + " ms.");
	} else {
		appendStatus("Segmentation failed: " + result.error);
	}
}

void ofApp::rebuildMaskOverlay(const ofxGgmlSegmentationResult & result) {
	clearMask();
	if (!result.success || result.masks.empty()) {
		return;
	}

	const auto & mask = result.masks.front();
	if (mask.width <= 0 || mask.height <= 0 || mask.pixels.empty()) {
		return;
	}

	ofPixels pixels;
	pixels.allocate(mask.width, mask.height, OF_PIXELS_RGBA);
	for (int y = 0; y < mask.height; ++y) {
		for (int x = 0; x < mask.width; ++x) {
			const unsigned char value = maskValueAt(mask, x, y);
			const unsigned char alpha = value > 0 ? 138 : 0;
			pixels.setColor(x, y, ofColor(40, 205, 255, alpha));
		}
	}
	maskOverlay.setFromPixels(pixels);
}

void ofApp::clearMask() {
	if (maskOverlay.isAllocated()) {
		maskOverlay.clear();
	}
}

void ofApp::appendStatus(const std::string & line) {
	status = line;
	logLines.push_back(line);
	const size_t maxLines = 8;
	if (logLines.size() > maxLines) {
		logLines.erase(logLines.begin(), logLines.end() - static_cast<long>(maxLines));
	}
}

std::vector<unsigned char> ofApp::makeRgbBuffer() const {
	std::vector<unsigned char> rgb;
	if (!sourceImage.isAllocated()) {
		return rgb;
	}
	const ofPixels & pixels = sourceImage.getPixels();
	rgb.reserve(static_cast<size_t>(pixels.getWidth()) *
		static_cast<size_t>(pixels.getHeight()) * 3u);
	for (int y = 0; y < pixels.getHeight(); ++y) {
		for (int x = 0; x < pixels.getWidth(); ++x) {
			const ofColor color = pixels.getColor(x, y);
			rgb.push_back(color.r);
			rgb.push_back(color.g);
			rgb.push_back(color.b);
		}
	}
	return rgb;
}

ofVec2f ofApp::screenToNormalizedImagePoint(int x, int y) const {
	if (imageRect.getWidth() <= 0.0f || imageRect.getHeight() <= 0.0f) {
		return {0.5f, 0.5f};
	}
	return {
		ofClamp((static_cast<float>(x) - imageRect.x) / imageRect.getWidth(), 0.0f, 1.0f),
		ofClamp((static_cast<float>(y) - imageRect.y) / imageRect.getHeight(), 0.0f, 1.0f)
	};
}

ofVec2f ofApp::normalizedToScreenPoint(const ofVec2f & point) const {
	return {
		imageRect.x + point.x * imageRect.getWidth(),
		imageRect.y + point.y * imageRect.getHeight()
	};
}

ofxGgmlSegmentationResult ofApp::runPreviewSegmentation(
	const ofxGgmlSegmentationRequest & request) const {
	ofxGgmlSegmentationResult result;
	result.success = true;
	result.backendName = "preview segmentation";
	result.imagePath = request.imagePath;

	ofxGgmlSegmentationMask mask;
	mask.maskId = "preview-point-mask";
	mask.width = std::max(1, request.imageWidth);
	mask.height = std::max(1, request.imageHeight);
	mask.score = 1.0f;
	mask.pixels.assign(
		static_cast<size_t>(mask.width) * static_cast<size_t>(mask.height),
		0);

	const ofxGgmlSegmentationPoint point = request.points.empty()
		? ofxGgmlSegmentationPoint{0.5f, 0.5f, true}
		: request.points.front();
	const float cx = point.x * static_cast<float>(mask.width);
	const float cy = point.y * static_cast<float>(mask.height);
	const float radius = std::max(mask.width, mask.height) * 0.16f;
	for (int y = 0; y < mask.height; ++y) {
		for (int x = 0; x < mask.width; ++x) {
			const float dx = static_cast<float>(x) - cx;
			const float dy = static_cast<float>(y) - cy;
			const float distance = std::sqrt(dx * dx + dy * dy);
			if (distance <= radius) {
				const size_t index = static_cast<size_t>(y) *
					static_cast<size_t>(mask.width) +
					static_cast<size_t>(x);
				mask.pixels[index] = 255;
			}
		}
	}
	mask.metadata.push_back({"mode", "preview"});
	result.masks.push_back(std::move(mask));
	return result;
}

void ofApp::draw() {
	ofBackgroundGradient(ofColor(17, 21, 28), ofColor(7, 9, 12), OF_GRADIENT_CIRCULAR);
	ofSetColor(245);
	ofDrawBitmapStringHighlight("ofxGgml SAM Example", kMargin, kHeaderY);
	ofSetColor(215);
	ofDrawBitmapString(
		"Click image: move point  |  S: segment  |  O: load default image  |  C: clear mask  |  Drop image file",
		kMargin,
		kHelpY);
	ofDrawBitmapString(
		"Backend: " + backendName + (usingPreviewBackend ? " (install sam.cpp + model for real masks)" : ""),
		kMargin,
		kHelpY + 22.0f);
	ofDrawBitmapString("Model: " + modelPath, kMargin, kHelpY + 44.0f);

	if (sourceImage.isAllocated()) {
		ofSetColor(255);
		sourceImage.draw(imageRect);
		if (maskOverlay.isAllocated()) {
			ofEnableAlphaBlending();
			ofSetColor(255);
			maskOverlay.draw(imageRect);
			ofDisableAlphaBlending();
		}
		if (hasPromptPoint) {
			const ofVec2f p = normalizedToScreenPoint(promptPoint);
			ofSetColor(255, 80, 80);
			ofDrawCircle(p, 7.0f);
			ofSetColor(255);
			ofNoFill();
			ofDrawCircle(p, 13.0f);
			ofFill();
		}
		ofSetColor(120);
		ofNoFill();
		ofDrawRectangle(imageRect);
		ofFill();
	}

	float y = imageRect.getBottom() + 26.0f;
	ofSetColor(120, 220, 255);
	ofDrawBitmapString(status, kMargin, y);
	y += 26.0f;
	ofSetColor(200);
	for (const auto & line : logLines) {
		ofDrawBitmapString(line, kMargin, y);
		y += kLogLineHeight;
	}
}

void ofApp::keyPressed(int key) {
	if (key == 's' || key == 'S') {
		runSegmentation();
	} else if (key == 'o' || key == 'O') {
		loadDefaultImage();
	} else if (key == 'c' || key == 'C') {
		clearMask();
		appendStatus("Mask cleared.");
	}
}

void ofApp::mousePressed(int x, int y, int button) {
	if (button != OF_MOUSE_BUTTON_LEFT || !imageRect.inside(x, y)) {
		return;
	}
	promptPoint = screenToNormalizedImagePoint(x, y);
	hasPromptPoint = true;
	clearMask();
	appendStatus("Point prompt set to " +
		ofToString(promptPoint.x, 3) + ", " + ofToString(promptPoint.y, 3) + ".");
}

void ofApp::dragEvent(ofDragInfo dragInfo) {
    if (dragInfo.files.empty()) {
        return;
    }
    const std::string path = dragInfo.files.front().string();
    if (loadImage(path)) {
        updateImageLayout();
        appendStatus("Dropped image loaded.");
    } else {
        appendStatus("Failed to load dropped image: " + path);
    }
}
