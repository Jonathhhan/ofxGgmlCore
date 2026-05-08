#include "ofApp.h"

void ofApp::setup() {
	ofSetWindowTitle("ofxGgml rewrite");
	ofBackground(12);

	ofxGgml runtime;
	auto result = runtime.setup();
	status = result ? "runtime ready: " + runtime.backendName() : result.error().message;
}

void ofApp::draw() {
	ofSetColor(240);
	ofDrawBitmapString("ofxGgml rewrite main", 32, 40);
	ofDrawBitmapString(status, 32, 70);
	ofDrawBitmapString("legacy-full keeps the previous broad framework.", 32, 100);
}
