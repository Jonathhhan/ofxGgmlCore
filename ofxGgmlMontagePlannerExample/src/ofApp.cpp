#include "ofApp.h"

#include <algorithm>

namespace {
std::string formatTimestamp(double seconds) {
	const int totalMilliseconds = static_cast<int>(std::max(0.0, seconds) * 1000.0);
	const int milliseconds = totalMilliseconds % 1000;
	const int totalSeconds = totalMilliseconds / 1000;
	const int secs = totalSeconds % 60;
	const int totalMinutes = totalSeconds / 60;
	const int mins = totalMinutes % 60;
	const int hours = totalMinutes / 60;
	return ofToString(hours, 2, '0') + ":" +
		ofToString(mins, 2, '0') + ":" +
		ofToString(secs, 2, '0') + "," +
		ofToString(milliseconds, 3, '0');
}
} // namespace

void ofApp::setup() {
ofSetWindowTitle("ofxGgml - Montage Planner Companion Example");
ofBackground(14, 14, 18);
request.goal = "Build a short energetic montage about local creative AI tools";
request.maxClips = 4;
request.minScore = 0.08;
request.preRollSeconds = 0.25;
request.postRollSeconds = 0.35;
request.targetDurationSeconds = 28.0;
request.fallbackReelName = "AX";
request.sourceFilePath = "media/interview_selects.mov";
request.segments = {
{ "clip-001", "AX", 12.0, 18.2, "Local tools let artists iterate privately before sharing results.", { "local", "artists", "iterate" } },
{ "clip-002", "AX", 25.0, 34.4, "The workflow starts with research, then turns citations into a script.", { "research", "citations", "script" } },
{ "clip-003", "BR", 44.0, 52.5, "Visual references help keep the edit grounded and consistent.", { "visual", "references", "edit" } },
{ "clip-004", "BR", 61.0, 70.0, "Exporting EDL and subtitles keeps the companion app out of the final NLE.", { "edl", "subtitles", "nle" } }
};
buildPlan();
}

void ofApp::buildPlan() {
result = ofxGgmlMontagePlanner::plan(request);
lines.clear();
lines.push_back("Extracted from removed GUI montage controls into a focused post-production example.");
lines.push_back("Demonstrates subtitle-driven clip selection, editor briefs, SRT/VTT, and EDL export helpers.");
lines.push_back("");
lines.push_back("Goal: " + request.goal);
lines.push_back(std::string("Plan: ") + (result.success ? "success" : "failed"));
if (!result.error.empty()) lines.push_back("Error: " + result.error);
lines.push_back(ofxGgmlMontagePlanner::summarizePlan(result.plan));
	lines.push_back("");
	for (const auto & clip : result.plan.clips) {
		lines.push_back("#" + ofToString(clip.index) + " " + clip.reelName + " " +
			formatTimestamp(clip.startSeconds) + " -> " +
			formatTimestamp(clip.endSeconds) + "  " + clip.note);
	}
const auto subtitleTrack = ofxGgmlMontagePlanner::buildSubtitleTrack(result.plan, "MONTAGE");
srt = ofxGgmlMontagePlanner::buildSrt(subtitleTrack);
edl = ofxGgmlMontagePlanner::buildEdlWithAudio(result.plan, "OFXGGML_MONTAGE", 25);
lines.push_back("");
lines.push_back("Press B to rebuild, S to save SRT and EDL exports.");
status = "Plan ready with " + ofToString(result.plan.clips.size()) + " clips.";
}

void ofApp::saveExports() {
const auto dir = ofToDataPath("generated/montage", true);
ofDirectory::createDirectory(dir, true, true);
const bool srtOk = ofBufferToFile(ofFilePath::join(dir, "montage.srt"), ofBuffer(srt), true);
const bool edlOk = ofBufferToFile(ofFilePath::join(dir, "montage.edl"), ofBuffer(edl), true);
status = (srtOk && edlOk) ? "Saved generated/montage/montage.srt and montage.edl" : "Failed to save exports.";
}

void ofApp::draw() {
ofBackgroundGradient(ofColor(22, 18, 18), ofColor(8, 8, 10), OF_GRADIENT_CIRCULAR);
ofSetColor(245);
ofDrawBitmapStringHighlight("ofxGgml Montage Planner Example", 28, 30);
float y = 68;
ofSetColor(220);
for (const auto & line : lines) {
ofDrawBitmapString(line, 28, y);
y += 18;
}
ofSetColor(255, 205, 120);
ofDrawBitmapString(status, 28, ofGetHeight() - 34);
}

void ofApp::keyPressed(int key) {
if (key == 'b' || key == 'B') buildPlan();
if (key == 's' || key == 'S') saveExports();
}
