#pragma once

#include "ofMain.h"

#include <map>
#include <string>
#include <utility>
#include <vector>

namespace ofxGgmlCollaborativeWorkflowDetail {
inline ofJson stringArrayToJson(const std::vector<std::string> & values) {
	ofJson array = ofJson::array();
	for (const auto & value : values) {
		array.push_back(value);
	}
	return array;
}
} // namespace ofxGgmlCollaborativeWorkflowDetail

struct ofxGgmlCollaborativeParticipant {
	std::string id;
	std::string displayName;
	std::string role;
	std::vector<std::string> permissions;
	std::vector<std::string> presenceSignals;
	std::map<std::string, std::string> metadata;

	void addPermission(const std::string & permission) {
		if (!permission.empty()) {
			permissions.push_back(permission);
		}
	}

	void addPresenceSignal(const std::string & signal) {
		if (!signal.empty()) {
			presenceSignals.push_back(signal);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["display_name"] = displayName;
		json["role"] = role;
		json["permissions"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(permissions);
		json["presence_signals"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(presenceSignals);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlRealtimeChannel {
	std::string id;
	std::string label;
	std::string channelType;
	std::string transportBoundary;
	int latencyBudgetMs = 0;
	std::vector<std::string> payloadKeys;
	std::vector<std::string> failureModes;
	std::map<std::string, std::string> metadata;

	void addPayloadKey(const std::string & key) {
		if (!key.empty()) {
			payloadKeys.push_back(key);
		}
	}

	void addFailureMode(const std::string & mode) {
		if (!mode.empty()) {
			failureModes.push_back(mode);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["label"] = label;
		json["channel_type"] = channelType;
		json["transport_boundary"] = transportBoundary;
		json["latency_budget_ms"] = latencyBudgetMs;
		json["payload_keys"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(payloadKeys);
		json["failure_modes"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(failureModes);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlCollaborativeCheckpoint {
	std::string id;
	std::string label;
	std::string approvalMode = "explicit";
	std::vector<std::string> requiredRoles;
	std::vector<std::string> evidenceRefs;
	std::map<std::string, std::string> metadata;

	void addRequiredRole(const std::string & role) {
		if (!role.empty()) {
			requiredRoles.push_back(role);
		}
	}

	void addEvidenceRef(const std::string & ref) {
		if (!ref.empty()) {
			evidenceRefs.push_back(ref);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["label"] = label;
		json["approval_mode"] = approvalMode;
		json["required_roles"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(requiredRoles);
		json["evidence_refs"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(evidenceRefs);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlCollaborativeWorkflowSpace {
	std::string schemaVersion = "ofxGgml.collaborative_workflow.v1";
	std::string spaceId;
	std::string title;
	std::string sessionMode;
	std::string projectMemoryRef;
	std::string workflowManifestRef;
	std::vector<ofxGgmlCollaborativeParticipant> participants;
	std::vector<ofxGgmlRealtimeChannel> channels;
	std::vector<ofxGgmlCollaborativeCheckpoint> checkpoints;
	std::vector<std::string> syncRules;
	std::vector<std::string> reviewNotes;
	std::map<std::string, std::string> metadata;

	void addParticipant(const ofxGgmlCollaborativeParticipant & participant) {
		participants.push_back(participant);
	}

	void addChannel(const ofxGgmlRealtimeChannel & channel) {
		channels.push_back(channel);
	}

	void addCheckpoint(const ofxGgmlCollaborativeCheckpoint & checkpoint) {
		checkpoints.push_back(checkpoint);
	}

	void addSyncRule(const std::string & rule) {
		if (!rule.empty()) {
			syncRules.push_back(rule);
		}
	}

	void addReviewNote(const std::string & note) {
		if (!note.empty()) {
			reviewNotes.push_back(note);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["schema_version"] = schemaVersion;
		json["space_id"] = spaceId;
		json["title"] = title;
		json["session_mode"] = sessionMode;
		json["project_memory_ref"] = projectMemoryRef;
		json["workflow_manifest_ref"] = workflowManifestRef;

		ofJson participantArray = ofJson::array();
		for (const auto & participant : participants) {
			participantArray.push_back(participant.toJson());
		}
		json["participants"] = std::move(participantArray);

		ofJson channelArray = ofJson::array();
		for (const auto & channel : channels) {
			channelArray.push_back(channel.toJson());
		}
		json["channels"] = std::move(channelArray);

		ofJson checkpointArray = ofJson::array();
		for (const auto & checkpoint : checkpoints) {
			checkpointArray.push_back(checkpoint.toJson());
		}
		json["checkpoints"] = std::move(checkpointArray);

		json["sync_rules"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(syncRules);
		json["review_notes"] =
			ofxGgmlCollaborativeWorkflowDetail::stringArrayToJson(reviewNotes);

		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}

	std::string toJsonString() const {
		return toJson().dump();
	}
};

inline ofxGgmlCollaborativeParticipant ofxGgmlMakeCollaborativeParticipant(
	const std::string & id,
	const std::string & displayName,
	const std::string & role) {
	ofxGgmlCollaborativeParticipant participant;
	participant.id = id;
	participant.displayName = displayName;
	participant.role = role;
	return participant;
}

inline ofxGgmlRealtimeChannel ofxGgmlMakeRealtimeChannel(
	const std::string & id,
	const std::string & label,
	const std::string & channelType,
	const std::string & transportBoundary) {
	ofxGgmlRealtimeChannel channel;
	channel.id = id;
	channel.label = label;
	channel.channelType = channelType;
	channel.transportBoundary = transportBoundary;
	return channel;
}

inline ofxGgmlCollaborativeCheckpoint ofxGgmlMakeCollaborativeCheckpoint(
	const std::string & id,
	const std::string & label,
	const std::string & approvalMode = "explicit") {
	ofxGgmlCollaborativeCheckpoint checkpoint;
	checkpoint.id = id;
	checkpoint.label = label;
	checkpoint.approvalMode = approvalMode;
	return checkpoint;
}

inline ofxGgmlCollaborativeWorkflowSpace ofxGgmlDefaultCollaborativeWorkflowSpace() {
	ofxGgmlCollaborativeWorkflowSpace space;
	space.spaceId = "ecosystem-collaborative-realtime";
	space.title = "Collaborative and real-time workflow space";
	space.sessionMode = "local-first-assisted-collaboration";
	space.projectMemoryRef = "ofxGgml.companion_project_memory.v1";
	space.workflowManifestRef = "ofxGgml.workflow_manifest.v1";

	auto hostOperator = ofxGgmlMakeCollaborativeParticipant(
		"host_operator",
		"Host operator",
		"owner");
	hostOperator.addPermission("approve_mutations");
	hostOperator.addPermission("resolve_conflicts");
	hostOperator.addPresenceSignal("active_workspace");
	hostOperator.addPresenceSignal("approval_available");
	space.addParticipant(hostOperator);

	auto collaborator = ofxGgmlMakeCollaborativeParticipant(
		"human_collaborator",
		"Human collaborator",
		"reviewer");
	collaborator.addPermission("comment");
	collaborator.addPermission("propose_revision");
	collaborator.addPresenceSignal("cursor_or_timeline_focus");
	collaborator.addPresenceSignal("review_state");
	space.addParticipant(collaborator);

	auto assistantFacilitator = ofxGgmlMakeCollaborativeParticipant(
		"assistant_facilitator",
		"Assistant facilitator",
		"assistant");
	assistantFacilitator.addPermission("summarize_context");
	assistantFacilitator.addPermission("draft_handoff");
	assistantFacilitator.addPresenceSignal("streaming_status");
	assistantFacilitator.addPresenceSignal("pending_tool_requests");
	space.addParticipant(assistantFacilitator);

	auto runtimePeer = ofxGgmlMakeCollaborativeParticipant(
		"companion_runtime",
		"Companion runtime",
		"runtime");
	runtimePeer.addPermission("publish_preview_artifacts");
	runtimePeer.addPermission("report_runtime_health");
	runtimePeer.addPresenceSignal("queue_status");
	runtimePeer.addPresenceSignal("preview_freshness");
	space.addParticipant(runtimePeer);

	auto sharedContext = ofxGgmlMakeRealtimeChannel(
		"shared_context",
		"Shared context state",
		"state_sync",
		"host application");
	sharedContext.latencyBudgetMs = 250;
	sharedContext.addPayloadKey("project_memory_ref");
	sharedContext.addPayloadKey("active_manifest_ref");
	sharedContext.addPayloadKey("focused_items");
	sharedContext.addFailureMode("stale context snapshot");
	space.addChannel(sharedContext);

	auto approvalQueue = ofxGgmlMakeRealtimeChannel(
		"approval_queue",
		"Approval queue",
		"approval",
		"host application");
	approvalQueue.latencyBudgetMs = 500;
	approvalQueue.addPayloadKey("approval_requests");
	approvalQueue.addPayloadKey("risk_notes");
	approvalQueue.addPayloadKey("decision_state");
	approvalQueue.addFailureMode("approval denied");
	space.addChannel(approvalQueue);

	auto previewStream = ofxGgmlMakeRealtimeChannel(
		"realtime_preview",
		"Realtime preview stream",
		"preview",
		"companion renderer");
	previewStream.latencyBudgetMs = 1000;
	previewStream.addPayloadKey("timeline_position");
	previewStream.addPayloadKey("preview_artifact_refs");
	previewStream.addPayloadKey("warnings");
	previewStream.addFailureMode("preview dropped");
	space.addChannel(previewStream);

	auto artifactStream = ofxGgmlMakeRealtimeChannel(
		"artifact_stream",
		"Artifact handoff stream",
		"artifact_handoff",
		"workflow manifest");
	artifactStream.latencyBudgetMs = 1500;
	artifactStream.addPayloadKey("input_artifacts");
	artifactStream.addPayloadKey("output_artifacts");
	artifactStream.addPayloadKey("provenance");
	artifactStream.addFailureMode("artifact unavailable");
	space.addChannel(artifactStream);

	auto planReview = ofxGgmlMakeCollaborativeCheckpoint(
		"plan_review",
		"Plan review");
	planReview.addRequiredRole("owner");
	planReview.addRequiredRole("reviewer");
	planReview.addEvidenceRef("workflow_manifest:planned_steps");
	planReview.addEvidenceRef("assistant_team:review_notes");
	space.addCheckpoint(planReview);

	auto editLock = ofxGgmlMakeCollaborativeCheckpoint(
		"edit_lock",
		"Concurrent edit lock");
	editLock.addRequiredRole("owner");
	editLock.addEvidenceRef("project_memory:accepted_revisions");
	editLock.addEvidenceRef("approval_queue:decision_state");
	space.addCheckpoint(editLock);

	auto publishHandoff = ofxGgmlMakeCollaborativeCheckpoint(
		"publish_handoff",
		"Publish or render handoff");
	publishHandoff.addRequiredRole("owner");
	publishHandoff.addRequiredRole("runtime");
	publishHandoff.addEvidenceRef("workflow_manifest:output_artifacts");
	publishHandoff.addEvidenceRef("trust_evaluation:approval_rules");
	space.addCheckpoint(publishHandoff);

	space.addSyncRule("Keep collaborative state local-first and host-owned unless an integration explicitly exports it.");
	space.addSyncRule("Treat assistant suggestions as proposals until an approved participant accepts them.");
	space.addSyncRule("Persist accepted decisions, conflicts, and provenance into project memory or workflow manifests.");
	space.addReviewNote("Use this contract to describe collaborative surfaces before adding network transports.");
	space.addReviewNote("Expose dropped preview frames, stale context, and unresolved approvals as visible workflow warnings.");

	return space;
}
