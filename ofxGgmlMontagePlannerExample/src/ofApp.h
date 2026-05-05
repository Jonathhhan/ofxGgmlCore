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
void buildPlan();
void saveExports();

ofxGgmlMontagePlannerRequest request;
ofxGgmlMontagePlannerResult result;
std::vector<std::string> lines;
std::string srt;
std::string edl;
std::string status;
};
