#pragma once

#include "ofMain.h"

#include <map>
#include <string>
#include <vector>

struct ofxGgmlContinuityRule {
	std::string id;
	std::string scope;
	std::string description;
	std::string sourceRef;
	std::string severity = "required";
	std::map<std::string, std::string> metadata;

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["scope"] = scope;
		json["description"] = description;
		json["source_ref"] = sourceRef;
		json["severity"] = severity;
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlStyleConstraint {
	std::string id;
	std::string category;
	std::string value;
	std::string rationale;
	std::string sourceRef;
	std::map<std::string, std::string> metadata;

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["category"] = category;
		json["value"] = value;
		json["rationale"] = rationale;
		json["source_ref"] = sourceRef;
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlReusableAssetReference {
	std::string id;
	std::string type;
	std::string title;
	std::string uri;
	std::string reuseGuidance;
	std::string license;
	std::vector<std::string> tags;
	std::map<std::string, std::string> metadata;

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["type"] = type;
		json["title"] = title;
		json["uri"] = uri;
		json["reuse_guidance"] = reuseGuidance;
		json["license"] = license;
		json["tags"] = toStringArray(tags);
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

struct ofxGgmlContinuityAssetLedger {
	std::string schemaVersion = "ofxGgml.continuity_asset_ledger.v1";
	std::string projectId;
	std::string title;
	std::string manifestRef;
	std::string memoryRef;
	std::vector<ofxGgmlContinuityRule> continuityRules;
	std::vector<ofxGgmlStyleConstraint> styleConstraints;
	std::vector<ofxGgmlReusableAssetReference> reusableAssets;
	std::vector<std::string> reviewNotes;
	std::map<std::string, std::string> metadata;

	void addContinuityRule(const ofxGgmlContinuityRule & rule) {
		continuityRules.push_back(rule);
	}

	void addStyleConstraint(const ofxGgmlStyleConstraint & constraint) {
		styleConstraints.push_back(constraint);
	}

	void addReusableAsset(const ofxGgmlReusableAssetReference & asset) {
		reusableAssets.push_back(asset);
	}

	void addReviewNote(const std::string & note) {
		if (!note.empty()) {
			reviewNotes.push_back(note);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["schema_version"] = schemaVersion;
		json["project_id"] = projectId;
		json["title"] = title;
		json["manifest_ref"] = manifestRef;
		json["memory_ref"] = memoryRef;

		ofJson ruleArray = ofJson::array();
		for (const auto & rule : continuityRules) {
			ruleArray.push_back(rule.toJson());
		}
		json["continuity_rules"] = std::move(ruleArray);

		ofJson styleArray = ofJson::array();
		for (const auto & constraint : styleConstraints) {
			styleArray.push_back(constraint.toJson());
		}
		json["style_constraints"] = std::move(styleArray);

		ofJson assetArray = ofJson::array();
		for (const auto & asset : reusableAssets) {
			assetArray.push_back(asset.toJson());
		}
		json["reusable_assets"] = std::move(assetArray);
		json["review_notes"] = toStringArray(reviewNotes);

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

inline ofxGgmlContinuityRule ofxGgmlMakeContinuityRule(
	const std::string & id,
	const std::string & scope,
	const std::string & description,
	const std::string & sourceRef = "") {
	ofxGgmlContinuityRule rule;
	rule.id = id;
	rule.scope = scope;
	rule.description = description;
	rule.sourceRef = sourceRef;
	return rule;
}

inline ofxGgmlStyleConstraint ofxGgmlMakeStyleConstraint(
	const std::string & id,
	const std::string & category,
	const std::string & value,
	const std::string & rationale = "") {
	ofxGgmlStyleConstraint constraint;
	constraint.id = id;
	constraint.category = category;
	constraint.value = value;
	constraint.rationale = rationale;
	return constraint;
}

inline ofxGgmlReusableAssetReference ofxGgmlMakeReusableAssetReference(
	const std::string & id,
	const std::string & type,
	const std::string & title,
	const std::string & uri = "") {
	ofxGgmlReusableAssetReference asset;
	asset.id = id;
	asset.type = type;
	asset.title = title;
	asset.uri = uri;
	return asset;
}

inline ofxGgmlContinuityAssetLedger ofxGgmlDefaultContinuityAssetLedger() {
	ofxGgmlContinuityAssetLedger ledger;
	ledger.projectId = "continuity-consistency-assets";
	ledger.title = "Continuity, consistency, and reusable assets";
	ledger.manifestRef = "ofxGgml.workflow_manifest.v1";
	ledger.memoryRef = "ofxGgml.companion_project_memory.v1";

	ledger.addContinuityRule(ofxGgmlMakeContinuityRule(
		"scene_identity",
		"long_form_video",
		"Preserve named characters, locations, props, and timeline facts across generated scenes.",
		"companion_project_memory:continuity_rules"));
	ledger.addContinuityRule(ofxGgmlMakeContinuityRule(
		"timeline_order",
		"edit_plan",
		"Keep scene order and causal transitions aligned with the approved workflow manifest.",
		"workflow_manifest:intermediate_outputs"));

	ledger.addStyleConstraint(ofxGgmlMakeStyleConstraint(
		"palette",
		"visual_style",
		"Reuse approved palette, lighting, and camera-language notes before generating new prompts.",
		"Protect style consistency across prompt batches and rendered outputs."));
	ledger.addStyleConstraint(ofxGgmlMakeStyleConstraint(
		"negative_style",
		"generation_guardrail",
		"Avoid flicker, identity drift, abrupt style changes, and broken continuity.",
		"Mirror long-video continuity defaults for downstream companion renderers."));

	auto heroReference = ofxGgmlMakeReusableAssetReference(
		"hero_reference",
		"image",
		"Approved hero reference",
		"memory:accepted_references/hero_reference");
	heroReference.reuseGuidance = "Use as the primary identity and palette reference for scene prompts.";
	heroReference.tags.push_back("identity");
	heroReference.tags.push_back("palette");
	ledger.addReusableAsset(heroReference);

	auto motifPrompt = ofxGgmlMakeReusableAssetReference(
		"motif_prompt",
		"prompt",
		"Approved recurring motif prompt",
		"memory:accepted_prompts/motif_prompt");
	motifPrompt.reuseGuidance = "Reuse or adapt when a scene needs visual continuity with prior accepted outputs.";
	motifPrompt.tags.push_back("prompt");
	motifPrompt.tags.push_back("motif");
	ledger.addReusableAsset(motifPrompt);

	ledger.addReviewNote("Review continuity rules before approving long-form prompt or render batches.");
	ledger.addReviewNote("Confirm asset licenses and source provenance before companion-tool reuse.");

	return ledger;
}
