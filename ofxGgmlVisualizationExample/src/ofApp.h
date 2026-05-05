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
void generatePreset();
void savePreset();

ofxGgmlMilkDropGenerator generator;
ofxGgmlMilkDropRequest request;
ofxGgmlMilkDropValidation validation;
std::string modelPath;
std::string presetText;
std::string status;
std::vector<std::string> lines;
};
