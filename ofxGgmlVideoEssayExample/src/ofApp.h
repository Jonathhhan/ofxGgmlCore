#pragma once

#include "ofMain.h"
#include "ofxGgmlCompanionWorkflows.h"

#include <string>
#include <vector>

class ofApp : public ofBaseApp {
public:
void setup();
void draw();
void keyPressed(int key);

private:
void rebuildPreview();
void runWorkflow();
void appendResultSummary(const ofxGgmlVideoEssayResult & result);

ofxGgmlVideoEssayWorkflow workflow;
ofxGgmlVideoEssayRequest request;
std::vector<std::string> lines;
std::string status;
};
