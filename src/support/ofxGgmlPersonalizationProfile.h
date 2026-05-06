#pragma once

#include "ofMain.h"

#include <map>
#include <string>
#include <utility>
#include <vector>

namespace ofxGgmlPersonalizationProfileDetail {
inline ofJson stringArrayToJson(const std::vector<std::string> & values) {
	ofJson array = ofJson::array();
	for (const auto & value : values) {
		array.push_back(value);
	}
	return array;
}
} // namespace ofxGgmlPersonalizationProfileDetail

struct ofxGgmlPersonalizationAdapter {
	std::string id;
	std::string label;
	std::string adapterType;
	std::string baseModelRef;
	std::string activationMode;
	float weight = 1.0f;
	std::vector<std::string> assetRefs;
	std::vector<std::string> requiredCapabilities;
	std::vector<std::string> safetyRequirements;
	std::map<std::string, std::string> metadata;

	void addAssetRef(const std::string & ref) {
		if (!ref.empty()) {
			assetRefs.push_back(ref);
		}
	}

	void addRequiredCapability(const std::string & capability) {
		if (!capability.empty()) {
			requiredCapabilities.push_back(capability);
		}
	}

	void addSafetyRequirement(const std::string & requirement) {
		if (!requirement.empty()) {
			safetyRequirements.push_back(requirement);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["label"] = label;
		json["adapter_type"] = adapterType;
		json["base_model_ref"] = baseModelRef;
		json["activation_mode"] = activationMode;
		json["weight"] = weight;
		json["asset_refs"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(assetRefs);
		json["required_capabilities"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(requiredCapabilities);
		json["safety_requirements"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(safetyRequirements);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlStyleProfile {
	std::string id;
	std::string name;
	std::string modality;
	std::string description;
	std::vector<std::string> positiveTraits;
	std::vector<std::string> negativeConstraints;
	std::vector<std::string> referenceRefs;
	std::map<std::string, std::string> metadata;

	void addPositiveTrait(const std::string & trait) {
		if (!trait.empty()) {
			positiveTraits.push_back(trait);
		}
	}

	void addNegativeConstraint(const std::string & constraint) {
		if (!constraint.empty()) {
			negativeConstraints.push_back(constraint);
		}
	}

	void addReferenceRef(const std::string & ref) {
		if (!ref.empty()) {
			referenceRefs.push_back(ref);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["name"] = name;
		json["modality"] = modality;
		json["description"] = description;
		json["positive_traits"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(positiveTraits);
		json["negative_constraints"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(negativeConstraints);
		json["reference_refs"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(referenceRefs);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlProjectPreset {
	std::string id;
	std::string name;
	std::string scope;
	std::string description;
	std::vector<std::string> styleProfileRefs;
	std::vector<std::string> defaultAdapterRefs;
	std::map<std::string, std::string> settings;
	std::vector<std::string> reviewNotes;
	std::map<std::string, std::string> metadata;

	void addStyleProfileRef(const std::string & ref) {
		if (!ref.empty()) {
			styleProfileRefs.push_back(ref);
		}
	}

	void addDefaultAdapterRef(const std::string & ref) {
		if (!ref.empty()) {
			defaultAdapterRefs.push_back(ref);
		}
	}

	void addReviewNote(const std::string & note) {
		if (!note.empty()) {
			reviewNotes.push_back(note);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["id"] = id;
		json["name"] = name;
		json["scope"] = scope;
		json["description"] = description;
		json["style_profile_refs"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(styleProfileRefs);
		json["default_adapter_refs"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(defaultAdapterRefs);
		json["settings"] = ofJson::object();
		for (const auto & item : settings) {
			json["settings"][item.first] = item.second;
		}
		json["review_notes"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(reviewNotes);
		json["metadata"] = ofJson::object();
		for (const auto & item : metadata) {
			json["metadata"][item.first] = item.second;
		}
		return json;
	}
};

struct ofxGgmlPersonalizationProfileSet {
	std::string schemaVersion = "ofxGgml.personalization_profile_set.v1";
	std::string profileSetId;
	std::string title;
	std::vector<ofxGgmlPersonalizationAdapter> adapters;
	std::vector<ofxGgmlStyleProfile> styleProfiles;
	std::vector<ofxGgmlProjectPreset> projectPresets;
	std::vector<std::string> adaptationRules;
	std::vector<std::string> reviewNotes;
	std::map<std::string, std::string> metadata;

	void addAdapter(const ofxGgmlPersonalizationAdapter & adapter) {
		adapters.push_back(adapter);
	}

	void addStyleProfile(const ofxGgmlStyleProfile & profile) {
		styleProfiles.push_back(profile);
	}

	void addProjectPreset(const ofxGgmlProjectPreset & preset) {
		projectPresets.push_back(preset);
	}

	void addAdaptationRule(const std::string & rule) {
		if (!rule.empty()) {
			adaptationRules.push_back(rule);
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
		json["profile_set_id"] = profileSetId;
		json["title"] = title;

		ofJson adapterArray = ofJson::array();
		for (const auto & adapter : adapters) {
			adapterArray.push_back(adapter.toJson());
		}
		json["adapters"] = std::move(adapterArray);

		ofJson styleArray = ofJson::array();
		for (const auto & profile : styleProfiles) {
			styleArray.push_back(profile.toJson());
		}
		json["style_profiles"] = std::move(styleArray);

		ofJson presetArray = ofJson::array();
		for (const auto & preset : projectPresets) {
			presetArray.push_back(preset.toJson());
		}
		json["project_presets"] = std::move(presetArray);

		json["adaptation_rules"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(adaptationRules);
		json["review_notes"] =
			ofxGgmlPersonalizationProfileDetail::stringArrayToJson(reviewNotes);

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

inline ofxGgmlPersonalizationAdapter ofxGgmlMakePersonalizationAdapter(
	const std::string & id,
	const std::string & label,
	const std::string & adapterType,
	const std::string & baseModelRef) {
	ofxGgmlPersonalizationAdapter adapter;
	adapter.id = id;
	adapter.label = label;
	adapter.adapterType = adapterType;
	adapter.baseModelRef = baseModelRef;
	return adapter;
}

inline ofxGgmlStyleProfile ofxGgmlMakeStyleProfile(
	const std::string & id,
	const std::string & name,
	const std::string & modality,
	const std::string & description) {
	ofxGgmlStyleProfile profile;
	profile.id = id;
	profile.name = name;
	profile.modality = modality;
	profile.description = description;
	return profile;
}

inline ofxGgmlProjectPreset ofxGgmlMakeProjectPreset(
	const std::string & id,
	const std::string & name,
	const std::string & scope,
	const std::string & description) {
	ofxGgmlProjectPreset preset;
	preset.id = id;
	preset.name = name;
	preset.scope = scope;
	preset.description = description;
	return preset;
}

inline ofxGgmlPersonalizationProfileSet ofxGgmlDefaultPersonalizationProfileSet() {
	ofxGgmlPersonalizationProfileSet profileSet;
	profileSet.profileSetId = "ecosystem-personalization-foundation";
	profileSet.title = "Personalization and adaptation profile set";

	auto textLora = ofxGgmlMakePersonalizationAdapter(
		"text_lora_adapter",
		"Text LoRA adapter",
		"lora",
		"ofxGgmlModelRegistry:text");
	textLora.activationMode = "explicit_project_preset";
	textLora.weight = 0.75f;
	textLora.addAssetRef("project_memory:accepted_prompts");
	textLora.addRequiredCapability("backend supports adapter attachment or companion-side merge");
	textLora.addSafetyRequirement("Record base model, adapter path, weight, and provenance before generation.");
	profileSet.addAdapter(textLora);

	auto mediaLora = ofxGgmlMakePersonalizationAdapter(
		"media_style_lora",
		"Media style LoRA adapter",
		"lora",
		"modality_runtime:image_or_video");
	mediaLora.activationMode = "companion_runtime_opt_in";
	mediaLora.weight = 0.6f;
	mediaLora.addAssetRef("continuity_asset_ledger:style_refs");
	mediaLora.addRequiredCapability("explicit modality opt-in");
	mediaLora.addSafetyRequirement("Keep rendered-media adapter loading outside core-only addon initialization.");
	profileSet.addAdapter(mediaLora);

	auto editorialStyle = ofxGgmlMakeStyleProfile(
		"editorial_clear",
		"Clear editorial voice",
		"text",
		"Reusable writing style for sourced summaries, scripts, and research notes.");
	editorialStyle.addPositiveTrait("concise");
	editorialStyle.addPositiveTrait("source-grounded");
	editorialStyle.addNegativeConstraint("unsupported claims");
	editorialStyle.addReferenceRef("citation_search:evidence_refs");
	profileSet.addStyleProfile(editorialStyle);

	auto cinematicStyle = ofxGgmlMakeStyleProfile(
		"cinematic_continuity",
		"Cinematic continuity",
		"visual",
		"Reusable visual style for prompts, storyboards, and render handoffs.");
	cinematicStyle.addPositiveTrait("consistent lighting");
	cinematicStyle.addPositiveTrait("scene continuity");
	cinematicStyle.addNegativeConstraint("untracked asset drift");
	cinematicStyle.addReferenceRef("continuity_asset_ledger:rules");
	profileSet.addStyleProfile(cinematicStyle);

	auto audioStyle = ofxGgmlMakeStyleProfile(
		"local_audio_sketch",
		"Local audio sketch",
		"audio",
		"Reusable musical direction for prompt and ABC notation sketches.");
	audioStyle.addPositiveTrait("project-safe motif reuse");
	audioStyle.addPositiveTrait("local-first generation");
	audioStyle.addNegativeConstraint("implicit external render dependency");
	audioStyle.addReferenceRef("companion_project_memory:style_notes");
	profileSet.addStyleProfile(audioStyle);

	auto researchPreset = ofxGgmlMakeProjectPreset(
		"source_grounded_research",
		"Source-grounded research preset",
		"research",
		"Combines citation evidence, editorial style, and project memory for repeatable research workflows.");
	researchPreset.addStyleProfileRef("editorial_clear");
	researchPreset.addDefaultAdapterRef("text_lora_adapter");
	researchPreset.settings["citation_mode"] = "required";
	researchPreset.settings["memory_scope"] = "project";
	researchPreset.addReviewNote("Keep unresolved citation warnings visible in downstream summaries.");
	profileSet.addProjectPreset(researchPreset);

	auto mediaPreset = ofxGgmlMakeProjectPreset(
		"companion_media_style",
		"Companion media style preset",
		"media",
		"Combines visual and audio style profiles with explicit companion-runtime adapter opt-in.");
	mediaPreset.addStyleProfileRef("cinematic_continuity");
	mediaPreset.addStyleProfileRef("local_audio_sketch");
	mediaPreset.addDefaultAdapterRef("media_style_lora");
	mediaPreset.settings["runtime_boundary"] = "companion";
	mediaPreset.settings["provenance"] = "required";
	mediaPreset.addReviewNote("Validate style/profile references before render or audio handoff.");
	profileSet.addProjectPreset(mediaPreset);

	profileSet.addAdaptationRule("Adapters are metadata declarations until a host or companion runtime explicitly attaches them.");
	profileSet.addAdaptationRule("Project presets should reference style profiles and adapters by stable ids, not direct file paths.");
	profileSet.addAdaptationRule("Record model, adapter, preset, and style provenance in manifests or project memory before downstream reuse.");
	profileSet.addReviewNote("Use this profile set to describe personalization boundaries before adding executable adapter loading.");
	profileSet.addReviewNote("Keep personalization local-first, inspectable, and reversible for project collaborators.");

	return profileSet;
}
