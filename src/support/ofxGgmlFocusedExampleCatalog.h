#pragma once

#include "ofMain.h"

#include <string>
#include <vector>

struct ofxGgmlFocusedExampleDescriptor {
	std::string id;
	std::string title;
	std::string summary;
	std::string workflowArea;
	std::vector<std::string> goals;
	std::vector<std::string> addonHeaders;
	std::vector<std::string> companionBoundaries;
	std::vector<std::string> setupNotes;
	std::vector<std::string> handoffContracts;
	std::vector<std::string> outputArtifacts;

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["title"] = title;
		json["summary"] = summary;
		json["workflow_area"] = workflowArea;
		json["goals"] = toStringArray(goals);
		json["addon_headers"] = toStringArray(addonHeaders);
		json["companion_boundaries"] = toStringArray(companionBoundaries);
		json["setup_notes"] = toStringArray(setupNotes);
		json["handoff_contracts"] = toStringArray(handoffContracts);
		json["output_artifacts"] = toStringArray(outputArtifacts);
		return json;
	}

private:
	static ofJson toStringArray(const std::vector<std::string> & values) {
		ofJson array = ofJson::array();
		for (const auto & value : values) {
			array.push_back(value);
		}
		return array;
	}
};

struct ofxGgmlFocusedExampleCatalog {
	std::string schemaVersion = "ofxGgml.focused_examples.v1";
	std::vector<ofxGgmlFocusedExampleDescriptor> examples;

	void addExample(const ofxGgmlFocusedExampleDescriptor & example) {
		examples.push_back(example);
	}

	ofJson toJson() const {
		ofJson json;
		json["schema_version"] = schemaVersion;
		ofJson exampleArray = ofJson::array();
		for (const auto & example : examples) {
			exampleArray.push_back(example.toJson());
		}
		json["examples"] = std::move(exampleArray);
		return json;
	}

	std::string toJsonString() const {
		return toJson().dump();
	}
};

inline ofxGgmlFocusedExampleCatalog ofxGgmlDefaultFocusedExampleCatalog() {
	ofxGgmlFocusedExampleCatalog catalog;

	ofxGgmlFocusedExampleDescriptor research;
	research.id = "research-citations";
	research.title = "Research and citation workflow";
	research.summary = "Crawl sources, extract cited notes, and hand off provenance-rich research artifacts.";
	research.workflowArea = "research";
	research.goals.push_back("crawl web or local source material");
	research.goals.push_back("extract source-grounded citations");
	research.goals.push_back("export manifest artifacts for downstream writing");
	research.addonHeaders.push_back("ofxGgmlWorkflows.h");
	research.setupNotes.push_back("configure crawler or local-source ingestion before running");
	research.handoffContracts.push_back("ofxGgmlWorkflowManifest");
	research.outputArtifacts.push_back("cited-notes markdown");
	research.outputArtifacts.push_back("research workflow manifest");
	catalog.addExample(research);

	ofxGgmlFocusedExampleDescriptor videoEssay;
	videoEssay.id = "companion-video-essay";
	videoEssay.title = "Companion video essay generation";
	videoEssay.summary = "Compose research, outline, script, subtitles, and visual-planning handoffs without making the core addon the application runtime.";
	videoEssay.workflowArea = "video-essay";
	videoEssay.goals.push_back("connect crawl-to-script stages with workflow manifests");
	videoEssay.goals.push_back("persist companion project memory across sessions");
	videoEssay.goals.push_back("route visual planning to companion-owned rendering tools");
	videoEssay.addonHeaders.push_back("ofxGgmlWorkflows.h");
	videoEssay.companionBoundaries.push_back("ofxGgmlCompanionWorkflows.h");
	videoEssay.setupNotes.push_back("keep rendering and timeline preview in the companion app");
	videoEssay.handoffContracts.push_back("ofxGgmlWorkflowManifest");
	videoEssay.handoffContracts.push_back("ofxGgmlCompanionProjectMemory");
	videoEssay.outputArtifacts.push_back("script outline");
	videoEssay.outputArtifacts.push_back("subtitle timing");
	videoEssay.outputArtifacts.push_back("video planning manifest");
	catalog.addExample(videoEssay);

	ofxGgmlFocusedExampleDescriptor speech;
	speech.id = "speech-subtitles";
	speech.title = "Speech and subtitle tooling";
	speech.summary = "Transcribe or draft spoken content, inspect SRT cues, and keep subtitle revision loops isolated.";
	speech.workflowArea = "speech";
	speech.goals.push_back("demonstrate speech-to-text setup");
	speech.goals.push_back("load and inspect subtitle cue timing");
	speech.goals.push_back("export review notes for companion editors");
	speech.addonHeaders.push_back("ofxGgmlModalities.h");
	speech.setupNotes.push_back("provide a local speech model or mock transcript source");
	speech.handoffContracts.push_back("ofxGgmlWorkflowManifest");
	speech.outputArtifacts.push_back("transcript text");
	speech.outputArtifacts.push_back("subtitle cues");
	catalog.addExample(speech);

	ofxGgmlFocusedExampleDescriptor coding;
	coding.id = "coding-assistant";
	coding.title = "Coding assistant integration";
	coding.summary = "Show project-memory, review, and local assistant surfaces in a small coding-oriented example.";
	coding.workflowArea = "coding";
	coding.goals.push_back("build prompts from repository context");
	coding.goals.push_back("summarize project memory for follow-up requests");
	coding.goals.push_back("keep workspace changes approval-first");
	coding.addonHeaders.push_back("ofxGgml.h");
	coding.setupNotes.push_back("point the assistant at an explicit workspace root");
	coding.handoffContracts.push_back("ofxGgmlCompanionProjectMemory");
	coding.outputArtifacts.push_back("review summary");
	coding.outputArtifacts.push_back("project-memory update");
	catalog.addExample(coding);

	ofxGgmlFocusedExampleDescriptor visual;
	visual.id = "clip-image-planning";
	visual.title = "CLIP image search and visual planning";
	visual.summary = "Search visual references, rank candidate images, and hand selected assets to planning workflows.";
	visual.workflowArea = "visual-planning";
	visual.goals.push_back("query reference-image providers");
	visual.goals.push_back("rank candidates with CLIP-style embeddings");
	visual.goals.push_back("record selected assets in workflow manifests");
	visual.addonHeaders.push_back("ofxGgmlWorkflows.h");
	visual.setupNotes.push_back("configure image-search providers and optional vision bridges explicitly");
	visual.handoffContracts.push_back("ofxGgmlWorkflowManifest");
	visual.outputArtifacts.push_back("ranked visual references");
	visual.outputArtifacts.push_back("selected asset manifest");
	catalog.addExample(visual);

	return catalog;
}
