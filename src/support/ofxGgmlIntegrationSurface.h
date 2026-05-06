#pragma once

#include "ofMain.h"

#include <map>
#include <string>
#include <utility>
#include <vector>

namespace ofxGgmlIntegrationSurfaceDetail {
inline ofJson stringArrayToJson(const std::vector<std::string> & values) {
	ofJson array = ofJson::array();
	for (const auto & value : values) {
		array.push_back(value);
	}
	return array;
}
} // namespace ofxGgmlIntegrationSurfaceDetail

struct ofxGgmlIntegrationEndpoint {
	std::string id;
	std::string label;
	std::string direction;
	std::string contract;
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
		json["direction"] = direction;
		json["contract"] = contract;
		json["payload_keys"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(payloadKeys);
		json["failure_modes"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(failureModes);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlIntegrationTarget {
	std::string id;
	std::string name;
	std::string category;
	std::string hostBoundary;
	std::string addonHeader;
	std::vector<ofxGgmlIntegrationEndpoint> endpoints;
	std::vector<std::string> requiredCapabilities;
	std::vector<std::string> setupRequirements;
	std::vector<std::string> safetyRequirements;
	std::vector<std::string> compatibilityNotes;
	std::map<std::string, std::string> metadata;

	void addEndpoint(const ofxGgmlIntegrationEndpoint & endpoint) {
		endpoints.push_back(endpoint);
	}

	void addRequiredCapability(const std::string & capability) {
		if (!capability.empty()) {
			requiredCapabilities.push_back(capability);
		}
	}

	void addSetupRequirement(const std::string & requirement) {
		if (!requirement.empty()) {
			setupRequirements.push_back(requirement);
		}
	}

	void addSafetyRequirement(const std::string & requirement) {
		if (!requirement.empty()) {
			safetyRequirements.push_back(requirement);
		}
	}

	void addCompatibilityNote(const std::string & note) {
		if (!note.empty()) {
			compatibilityNotes.push_back(note);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["name"] = name;
		json["category"] = category;
		json["host_boundary"] = hostBoundary;
		json["addon_header"] = addonHeader;

		ofJson endpointArray = ofJson::array();
		for (const auto & endpoint : endpoints) {
			endpointArray.push_back(endpoint.toJson());
		}
		json["endpoints"] = std::move(endpointArray);
		json["required_capabilities"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(requiredCapabilities);
		json["setup_requirements"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(setupRequirements);
		json["safety_requirements"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(safetyRequirements);
		json["compatibility_notes"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(compatibilityNotes);

		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlIntegrationSurface {
	std::string schemaVersion = "ofxGgml.integration_surface.v1";
	std::string surfaceId;
	std::string title;
	std::vector<ofxGgmlIntegrationTarget> targets;
	std::vector<std::string> boundaryRules;
	std::vector<std::string> reviewNotes;
	std::map<std::string, std::string> metadata;

	void addTarget(const ofxGgmlIntegrationTarget & target) {
		targets.push_back(target);
	}

	void addBoundaryRule(const std::string & rule) {
		if (!rule.empty()) {
			boundaryRules.push_back(rule);
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
		json["surface_id"] = surfaceId;
		json["title"] = title;

		ofJson targetArray = ofJson::array();
		for (const auto & target : targets) {
			targetArray.push_back(target.toJson());
		}
		json["targets"] = std::move(targetArray);
		json["boundary_rules"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(boundaryRules);
		json["review_notes"] =
			ofxGgmlIntegrationSurfaceDetail::stringArrayToJson(reviewNotes);

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

inline ofxGgmlIntegrationEndpoint ofxGgmlMakeIntegrationEndpoint(
	const std::string & id,
	const std::string & label,
	const std::string & direction,
	const std::string & contract) {
	ofxGgmlIntegrationEndpoint endpoint;
	endpoint.id = id;
	endpoint.label = label;
	endpoint.direction = direction;
	endpoint.contract = contract;
	return endpoint;
}

inline ofxGgmlIntegrationTarget ofxGgmlMakeIntegrationTarget(
	const std::string & id,
	const std::string & name,
	const std::string & category,
	const std::string & addonHeader) {
	ofxGgmlIntegrationTarget target;
	target.id = id;
	target.name = name;
	target.category = category;
	target.addonHeader = addonHeader;
	return target;
}

inline ofxGgmlIntegrationSurface ofxGgmlDefaultIntegrationSurface() {
	ofxGgmlIntegrationSurface surface;
	surface.surfaceId = "ecosystem-third-party-integrations";
	surface.title = "Third-party integration surface";

	auto editorShell = ofxGgmlMakeIntegrationTarget(
		"editor_shell",
		"Editor or IDE-like shell",
		"editor",
		"ofxGgmlAssistants.h");
	editorShell.hostBoundary = "host application";
	editorShell.addRequiredCapability("approval-first assistant actions");
	editorShell.addSetupRequirement("provide an explicit workspace root and project-memory storage path");
	editorShell.addSafetyRequirement("gate file edits, commands, and destructive operations through approval callbacks");
	editorShell.addCompatibilityNote("prefer structured assistant plans and patch previews over direct host mutation");
	auto editorContext = ofxGgmlMakeIntegrationEndpoint(
		"workspace_context",
		"Workspace context",
		"inbound",
		"ofxGgmlCompanionProjectMemory");
	editorContext.addPayloadKey("workspace_root");
	editorContext.addPayloadKey("focused_files");
	editorContext.addFailureMode("workspace unavailable");
	editorShell.addEndpoint(editorContext);
	auto editorPlan = ofxGgmlMakeIntegrationEndpoint(
		"assistant_plan",
		"Assistant plan and approvals",
		"outbound",
		"ofxGgmlAssistantTeamSpec");
	editorPlan.addPayloadKey("plan_steps");
	editorPlan.addPayloadKey("approval_requests");
	editorPlan.addFailureMode("approval denied");
	editorShell.addEndpoint(editorPlan);
	surface.addTarget(editorShell);

	auto renderer = ofxGgmlMakeIntegrationTarget(
		"external_renderer",
		"External renderer or media tool",
		"renderer",
		"ofxGgmlWorkflows.h");
	renderer.hostBoundary = "companion-owned runtime";
	renderer.addRequiredCapability("manifest artifact handoff");
	renderer.addSetupRequirement("map generated assets to host-visible paths before render submission");
	renderer.addSafetyRequirement("preserve source provenance and render settings in output artifacts");
	renderer.addCompatibilityNote("keep preview/render loops outside core addon initialization");
	auto renderRequest = ofxGgmlMakeIntegrationEndpoint(
		"render_request",
		"Render request",
		"outbound",
		"ofxGgmlWorkflowManifest");
	renderRequest.addPayloadKey("input_artifacts");
	renderRequest.addPayloadKey("render_settings");
	renderRequest.addFailureMode("missing media asset");
	renderer.addEndpoint(renderRequest);
	auto renderResult = ofxGgmlMakeIntegrationEndpoint(
		"render_result",
		"Render result",
		"inbound",
		"ofxGgmlWorkflowManifest");
	renderResult.addPayloadKey("output_artifacts");
	renderResult.addPayloadKey("warnings");
	renderResult.addFailureMode("render failed");
	renderer.addEndpoint(renderResult);
	surface.addTarget(renderer);

	auto searchPipeline = ofxGgmlMakeIntegrationTarget(
		"search_research_pipeline",
		"Search provider or research pipeline",
		"search_research",
		"ofxGgmlWorkflows.h");
	searchPipeline.hostBoundary = "replaceable provider";
	searchPipeline.addRequiredCapability("source-grounded retrieval");
	searchPipeline.addSetupRequirement("declare provider scope, freshness expectations, and citation fields");
	searchPipeline.addSafetyRequirement("record unresolved citations and source retrieval warnings");
	searchPipeline.addCompatibilityNote("downstream workflows should depend on citation contracts, not provider APIs");
	auto sourceQuery = ofxGgmlMakeIntegrationEndpoint(
		"source_query",
		"Source query",
		"outbound",
		"citation evidence refs");
	sourceQuery.addPayloadKey("query");
	sourceQuery.addPayloadKey("filters");
	sourceQuery.addFailureMode("provider unavailable");
	searchPipeline.addEndpoint(sourceQuery);
	auto sourceResults = ofxGgmlMakeIntegrationEndpoint(
		"source_results",
		"Source results",
		"inbound",
		"ofxGgmlWorkflowManifest");
	sourceResults.addPayloadKey("citations");
	sourceResults.addPayloadKey("evidence_refs");
	sourceResults.addFailureMode("empty evidence set");
	searchPipeline.addEndpoint(sourceResults);
	surface.addTarget(searchPipeline);

	auto hardwareRuntime = ofxGgmlMakeIntegrationTarget(
		"hardware_media_runtime",
		"Hardware or media runtime",
		"hardware_runtime",
		"ofxGgmlModalities.h");
	hardwareRuntime.hostBoundary = "optional runtime bridge";
	hardwareRuntime.addRequiredCapability("explicit modality opt-in");
	hardwareRuntime.addSetupRequirement("detect device/runtime availability before exposing the integration");
	hardwareRuntime.addSafetyRequirement("surface device failures, fallback choices, and user-visible diagnostics");
	hardwareRuntime.addCompatibilityNote("core-only users should not link hardware/media runtimes implicitly");
	auto runtimeProbe = ofxGgmlMakeIntegrationEndpoint(
		"runtime_probe",
		"Runtime probe",
		"inbound",
		"capability diagnostics");
	runtimeProbe.addPayloadKey("device_id");
	runtimeProbe.addPayloadKey("capabilities");
	runtimeProbe.addFailureMode("runtime unavailable");
	hardwareRuntime.addEndpoint(runtimeProbe);
	auto mediaJob = ofxGgmlMakeIntegrationEndpoint(
		"media_job",
		"Media processing job",
		"outbound",
		"explicit opt-in header");
	mediaJob.addPayloadKey("input_media");
	mediaJob.addPayloadKey("runtime_options");
	mediaJob.addFailureMode("unsupported format");
	hardwareRuntime.addEndpoint(mediaJob);
	surface.addTarget(hardwareRuntime);

	surface.addBoundaryRule("Integrations describe contracts and host boundaries before adding executable adapters.");
	surface.addBoundaryRule("Third-party runtimes remain optional and explicitly included through layered headers.");
	surface.addBoundaryRule("Prefer manifest, memory, citation, and assistant-team contracts over provider-specific payloads.");
	surface.addReviewNote("This surface is a metadata contract for companion and host applications.");
	surface.addReviewNote("Use target descriptors to keep editors, renderers, search providers, and hardware runtimes replaceable.");

	return surface;
}
