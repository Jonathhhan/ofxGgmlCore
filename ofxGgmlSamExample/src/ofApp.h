#pragma once

#include "ofMain.h"
#include "ofxGgmlModalities.h"
#include "inference/ofxGgmlSam3Adapters.h"

#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
	void setup();
	void update();
	void draw();
	void keyPressed(int key);
	void mousePressed(int x, int y, int button);
	void dragEvent(ofDragInfo dragInfo);

private:
	void configureSegmentationBackend();
	void loadDefaultImage();
	bool loadImage(const std::string & path);
	void createFallbackImage();
	void updateImageLayout();
	void runSegmentation();
	void rebuildMaskOverlay(const ofxGgmlSegmentationResult & result);
	void clearMask();
	void appendStatus(const std::string & line);
	std::vector<unsigned char> makeRgbBuffer() const;
	ofVec2f screenToNormalizedImagePoint(int x, int y) const;
	ofVec2f normalizedToScreenPoint(const ofVec2f & point) const;
	ofxGgmlSegmentationResult runPreviewSegmentation(
		const ofxGgmlSegmentationRequest & request) const;

	ofxGgmlSegmentationInference segmentation;
	ofImage sourceImage;
	ofImage maskOverlay;
	ofRectangle imageRect;
	ofVec2f promptPoint {0.5f, 0.5f};
	std::string imagePath;
	std::string modelPath;
	std::string backendName;
	std::string status;
	std::vector<std::string> logLines;
	bool hasPromptPoint = true;
	bool usingPreviewBackend = true;
};
