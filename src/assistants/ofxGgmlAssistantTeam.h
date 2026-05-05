#pragma once

#include "ofMain.h"

#include <map>
#include <string>
#include <vector>

struct ofxGgmlAssistantTeamRole {
	std::string id;
	std::string title;
	std::string responsibility;
	std::vector<std::string> allowedActions;
	std::vector<std::string> handoffTargets;
	std::map<std::string, std::string> metadata;

	void addAllowedAction(const std::string & action) {
		if (!action.empty()) {
			allowedActions.push_back(action);
		}
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
		json["responsibility"] = responsibility;
		json["allowed_actions"] = toStringArray(allowedActions);
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

struct ofxGgmlAssistantTeamHandoff {
	std::string fromRole;
	std::string toRole;
	std::string purpose;
	std::string approvalRequirement = "approval-first";
	std::vector<std::string> requiredContext;
	std::map<std::string, std::string> metadata;

	void addRequiredContext(const std::string & context) {
		if (!context.empty()) {
			requiredContext.push_back(context);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["from_role"] = fromRole;
		json["to_role"] = toRole;
		json["purpose"] = purpose;
		json["approval_requirement"] = approvalRequirement;
		json["required_context"] = toStringArray(requiredContext);
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

struct ofxGgmlAssistantTeamSpec {
	std::string schemaVersion = "ofxGgml.assistant_team.v1";
	std::string teamId;
	std::string title;
	std::string safetyModel = "approval-first";
	std::vector<ofxGgmlAssistantTeamRole> roles;
	std::vector<ofxGgmlAssistantTeamHandoff> handoffs;
	std::vector<std::string> workspaceRules;
	std::map<std::string, std::string> metadata;

	void addRole(const ofxGgmlAssistantTeamRole & role) {
		roles.push_back(role);
	}

	void addHandoff(const ofxGgmlAssistantTeamHandoff & handoff) {
		handoffs.push_back(handoff);
	}

	void addWorkspaceRule(const std::string & rule) {
		if (!rule.empty()) {
			workspaceRules.push_back(rule);
		}
	}

	ofJson toJson() const {
		ofJson json;
		json["schema_version"] = schemaVersion;
		json["team_id"] = teamId;
		json["title"] = title;
		json["safety_model"] = safetyModel;

		ofJson roleArray = ofJson::array();
		for (const auto & role : roles) {
			roleArray.push_back(role.toJson());
		}
		json["roles"] = std::move(roleArray);

		ofJson handoffArray = ofJson::array();
		for (const auto & handoff : handoffs) {
			handoffArray.push_back(handoff.toJson());
		}
		json["handoffs"] = std::move(handoffArray);

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

inline ofxGgmlAssistantTeamRole ofxGgmlMakeAssistantTeamRole(
	const std::string & id,
	const std::string & title,
	const std::string & responsibility) {
	ofxGgmlAssistantTeamRole role;
	role.id = id;
	role.title = title;
	role.responsibility = responsibility;
	return role;
}

inline ofxGgmlAssistantTeamHandoff ofxGgmlMakeAssistantTeamHandoff(
	const std::string & fromRole,
	const std::string & toRole,
	const std::string & purpose) {
	ofxGgmlAssistantTeamHandoff handoff;
	handoff.fromRole = fromRole;
	handoff.toRole = toRole;
	handoff.purpose = purpose;
	return handoff;
}

inline ofxGgmlAssistantTeamSpec ofxGgmlDefaultSpecialistAssistantTeam() {
	ofxGgmlAssistantTeamSpec team;
	team.teamId = "specialist-assistant-team";
	team.title = "Specialist assistant team";
	team.addWorkspaceRule("Workspace mutations require explicit approval.");
	team.addWorkspaceRule("Destructive actions stay disabled unless the host app enables them.");
	team.addWorkspaceRule("Every handoff carries task context, constraints, and review notes.");

	auto researcher = ofxGgmlMakeAssistantTeamRole(
		"researcher",
		"Researcher",
		"Collect source-grounded context, citations, and open questions.");
	researcher.addAllowedAction("crawl_sources");
	researcher.addAllowedAction("summarize_sources");
	researcher.addHandoffTarget("planner");
	team.addRole(researcher);

	auto planner = ofxGgmlMakeAssistantTeamRole(
		"planner",
		"Planner",
		"Turn approved context into actionable task or creative plans.");
	planner.addAllowedAction("draft_plan");
	planner.addAllowedAction("prepare_manifest");
	planner.addHandoffTarget("critic");
	planner.addHandoffTarget("editor");
	team.addRole(planner);

	auto critic = ofxGgmlMakeAssistantTeamRole(
		"critic",
		"Critic",
		"Review plans, outputs, and evidence before execution.");
	critic.addAllowedAction("review_output");
	critic.addAllowedAction("flag_risks");
	critic.addHandoffTarget("planner");
	critic.addHandoffTarget("editor");
	team.addRole(critic);

	auto editor = ofxGgmlMakeAssistantTeamRole(
		"editor",
		"Editor",
		"Revise approved text, prompts, and manifests without bypassing review.");
	editor.addAllowedAction("revise_text");
	editor.addAllowedAction("prepare_patch");
	editor.addHandoffTarget("critic");
	editor.addHandoffTarget("renderer");
	team.addRole(editor);

	auto renderer = ofxGgmlMakeAssistantTeamRole(
		"renderer",
		"Renderer",
		"Prepare companion-owned render or preview requests from approved assets.");
	renderer.addAllowedAction("prepare_render_request");
	renderer.addAllowedAction("record_artifacts");
	renderer.addHandoffTarget("critic");
	team.addRole(renderer);

	auto researchToPlan = ofxGgmlMakeAssistantTeamHandoff(
		"researcher",
		"planner",
		"Transfer grounded notes, accepted citations, and unknowns.");
	researchToPlan.addRequiredContext("accepted_sources");
	researchToPlan.addRequiredContext("open_questions");
	team.addHandoff(researchToPlan);

	auto planToCritic = ofxGgmlMakeAssistantTeamHandoff(
		"planner",
		"critic",
		"Review proposed sequence before editing or rendering.");
	planToCritic.addRequiredContext("planned_steps");
	planToCritic.addRequiredContext("approval_constraints");
	team.addHandoff(planToCritic);

	auto editorToRenderer = ofxGgmlMakeAssistantTeamHandoff(
		"editor",
		"renderer",
		"Hand approved prompts, subtitles, or manifests to companion preview tools.");
	editorToRenderer.addRequiredContext("approved_assets");
	editorToRenderer.addRequiredContext("review_notes");
	team.addHandoff(editorToRenderer);

	return team;
}
