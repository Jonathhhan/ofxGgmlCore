#pragma once

#include "ofMain.h"
#include "ofxGgmlModalities.h"
#include "inference/ofxGgmlImageSearch.h"
#include "inference/ofxGgmlMediaPromptGenerator.h"

#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
void setup();
void draw();
void keyPressed(int key);

private:
void configureMockBackends();
void rebuildPreview();
void runImageSearch();
void runRanking();
void runSegmentation();
void runDiffusionValidation();

ofxGgmlClipInference clip;
ofxGgmlImageSearch imageSearch;
ofxGgmlSegmentationInference segmentation;
ofxGgmlDiffusionInference diffusion;
std::vector<std::string> candidateImages;
std::vector<std::string> lines;
std::string status;
};
