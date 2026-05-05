#pragma once

#include "ofMain.h"

#include <map>
#include <string>
#include <vector>

struct ofxGgmlTimelineCopilotAnchor {
	std::string id;
	std::string label;
	double startSeconds = 0.0;
	double endSeconds = 0.0;
	std::string sourceRef;
	std::string notes;
	std::map<std::string, std::string> metadata;

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["label"] = label;
		json["start_seconds"] = startSeconds;
		json["end_seconds"] = endSeconds;
		json["source_ref"] = sourceRef;
		json["notes"] = notes;
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlTimelineCopilotLane {
	std::string id;
	std::string title;
	std::string workflowType;
	std::string assistantRole;
	std::string companionBoundary;
	std::vector<ofxGgmlTimelineCopilotAnchor> anchors;
	std::vector<std::string> handoffTargets;
	std::map<std::string, std::string> metadata;

	void addAnchor(const ofxGgmlTimelineCopilotAnchor & anchor) {
		anchors.push_back(anchor);
	}

	void addHandoffTarget(const std::string & target) {
		if (!target.empty()) {
			handoffTargets.push_back(target);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["title"] = title;
		json["workflow_type"] = workflowType;
		json["assistant_role"] = assistantRole;
		json["companion_boundary"] = companionBoundary;

		ofJson anchorArray = ofJson::array();
		for (const auto & anchor : anchors) {
			anchorArray.push_back(anchor.toJson());
		}
		json["timeline_anchors"] = std::move(anchorArray);
		json["handoff_targets"] = toStringArray(handoffTargets);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
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

struct ofxGgmlTimelineCopilotCheckpoint {
	std::string id;
	std::string label;
	double atSeconds = 0.0;
	std::string reviewFocus;
	std::string requiredApproval = "explicit";
	std::map<std::string, std::string> metadata;

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["label"] = label;
		json["at_seconds"] = atSeconds;
		json["review_focus"] = reviewFocus;
		json["required_approval"] = requiredApproval;
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlTimelineCopilotPlan {
	std::string schemaVersion = "ofxGgml.timeline_copilot.v1";
	std::string projectId;
	std::string title;
	std::string creativeIntent;
	std::string manifestHandoff;
	std::string memoryLink;
	std::vector<ofxGgmlTimelineCopilotLane> lanes;
	std::vector<ofxGgmlTimelineCopilotCheckpoint> reviewCheckpoints;
	std::vector<std::string> workspaceRules;
	std::map<std::string, std::string> metadata;

	void addLane(const ofxGgmlTimelineCopilotLane & lane) {
		lanes.push_back(lane);
	}

	void addReviewCheckpoint(const ofxGgmlTimelineCopilotCheckpoint & checkpoint) {
		reviewCheckpoints.push_back(checkpoint);
	}

	void addWorkspaceRule(const std::string & rule) {
		if (!rule.empty()) {
			workspaceRules.push_back(rule);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["schema_version"] = schemaVersion;
		json["project_id"] = projectId;
		json["title"] = title;
		json["creative_intent"] = creativeIntent;
		json["manifest_handoff"] = manifestHandoff;
		json["memory_link"] = memoryLink;

		ofJson laneArray = ofJson::array();
		for (const auto & lane : lanes) {
			laneArray.push_back(lane.toJson());
		}
		json["lanes"] = std::move(laneArray);

		ofJson checkpointArray = ofJson::array();
		for (const auto & checkpoint : reviewCheckpoints) {
			checkpointArray.push_back(checkpoint.toJson());
		}
		json["review_checkpoints"] = std::move(checkpointArray);
		json["workspace_rules"] = toStringArray(workspaceRules);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}

	std::string toJsonString() const {
		return toJson().dump();
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

inline ofxGgmlTimelineCopilotAnchor ofxGgmlMakeTimelineCopilotAnchor(
	const std::string & id,
	const std::string & label,
	double startSeconds,
	double endSeconds,
	const std::string & sourceRef = "") {
	ofxGgmlTimelineCopilotAnchor anchor;
	anchor.id = id;
	anchor.label = label;
	anchor.startSeconds = startSeconds;
	anchor.endSeconds = endSeconds;
	anchor.sourceRef = sourceRef;
	return anchor;
}

inline ofxGgmlTimelineCopilotLane ofxGgmlMakeTimelineCopilotLane(
	const std::string & id,
	const std::string & title,
	const std::string & workflowType,
	const std::string & assistantRole) {
	ofxGgmlTimelineCopilotLane lane;
	lane.id = id;
	lane.title = title;
	lane.workflowType = workflowType;
	lane.assistantRole = assistantRole;
	lane.companionBoundary = "ofxGgmlCompanionWorkflows.h";
	return lane;
}

inline ofxGgmlTimelineCopilotCheckpoint ofxGgmlMakeTimelineCopilotCheckpoint(
	const std::string & id,
	const std::string & label,
	double atSeconds,
	const std::string & reviewFocus) {
	ofxGgmlTimelineCopilotCheckpoint checkpoint;
	checkpoint.id = id;
	checkpoint.label = label;
	checkpoint.atSeconds = atSeconds;
	checkpoint.reviewFocus = reviewFocus;
	return checkpoint;
}

inline ofxGgmlTimelineCopilotPlan ofxGgmlDefaultTimelineCopilotPlan() {
	ofxGgmlTimelineCopilotPlan plan;
	plan.projectId = "timeline-companion-copilot";
	plan.title = "Timeline-aware companion copilot";
	plan.creativeIntent =
		"Coordinate media-creation assistants around inspectable timeline lanes and approval checkpoints.";
	plan.manifestHandoff = "ofxGgml.workflow_manifest.v1";
	plan.memoryLink = "ofxGgml.companion_project_memory.v1";
	plan.addWorkspaceRule("Keep media rendering and destructive timeline edits companion-owned.");
	plan.addWorkspaceRule("Record accepted prompts, references, and revisions before downstream generation.");
	plan.addWorkspaceRule("Require explicit approval at each review checkpoint.");

	auto videoEssay = ofxGgmlMakeTimelineCopilotLane(
		"video_essay",
		"Video essay planning",
		"video_essay_planning",
		"planner");
	videoEssay.addAnchor(ofxGgmlMakeTimelineCopilotAnchor(
		"outline",
		"Grounded outline",
		0.0,
		30.0,
		"workflow_manifest:intermediate_outputs"));
	videoEssay.addHandoffTarget("subtitle_revision");
	videoEssay.addHandoffTarget("generative_visuals");
	plan.addLane(videoEssay);

	auto montage = ofxGgmlMakeTimelineCopilotLane(
		"montage",
		"Montage building",
		"montage_building",
		"editor");
	montage.addAnchor(ofxGgmlMakeTimelineCopilotAnchor(
		"selects",
		"Subtitle-driven selects",
		30.0,
		60.0,
		"montage_preview"));
	montage.addHandoffTarget("critic");
	plan.addLane(montage);

	auto musicVideo = ofxGgmlMakeTimelineCopilotLane(
		"music_video",
		"Music-video planning",
		"music_video_planning",
		"planner");
	musicVideo.addAnchor(ofxGgmlMakeTimelineCopilotAnchor(
		"beat_map",
		"Beat and visual motif map",
		0.0,
		45.0,
		"companion_music"));
	musicVideo.addHandoffTarget("generative_visuals");
	plan.addLane(musicVideo);

	auto subtitles = ofxGgmlMakeTimelineCopilotLane(
		"subtitle_revision",
		"Subtitle editing and revision",
		"subtitle_revision",
		"editor");
	subtitles.addAnchor(ofxGgmlMakeTimelineCopilotAnchor(
		"caption_pass",
		"Caption timing review",
		0.0,
		90.0,
		"srt_track"));
	subtitles.addHandoffTarget("critic");
	plan.addLane(subtitles);

	auto visuals = ofxGgmlMakeTimelineCopilotLane(
		"generative_visuals",
		"Generative visual pipeline",
		"generative_visual_pipeline",
		"renderer");
	visuals.addAnchor(ofxGgmlMakeTimelineCopilotAnchor(
		"prompt_batch",
		"Approved prompt batch",
		60.0,
		120.0,
		"companion_project_memory:accepted_prompts"));
	visuals.addHandoffTarget("critic");
	plan.addLane(visuals);

	plan.addReviewCheckpoint(ofxGgmlMakeTimelineCopilotCheckpoint(
		"research_lock",
		"Research and outline approval",
		30.0,
		"citation quality and factual grounding"));
	plan.addReviewCheckpoint(ofxGgmlMakeTimelineCopilotCheckpoint(
		"edit_lock",
		"Edit plan approval",
		60.0,
		"timeline pacing, subtitle timing, and continuity"));
	plan.addReviewCheckpoint(ofxGgmlMakeTimelineCopilotCheckpoint(
		"render_lock",
		"Render request approval",
		120.0,
		"accepted assets, prompts, and companion-tool routing"));

	return plan;
}
