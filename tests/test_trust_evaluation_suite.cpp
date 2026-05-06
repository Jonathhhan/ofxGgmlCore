#include "catch2.hpp"
#include "../src/ofxGgmlWorkflows.h"

TEST_CASE("Trust evaluation suite exposes roadmap trust dimensions", "[trust_evaluation]") {
	const auto suite = ofxGgmlDefaultTrustEvaluationSuite();
	REQUIRE(suite.schemaVersion == "ofxGgml.trust_evaluation_suite.v1");
	REQUIRE(suite.manifestRef == "ofxGgml.workflow_manifest.v1");
	REQUIRE(suite.assistantTeamRef == "ofxGgml.assistant_team.v1");
	REQUIRE(suite.metrics.size() == 5);
	REQUIRE(suite.cases.size() == 5);
	REQUIRE(suite.approvalRules.size() == 2);
	REQUIRE(suite.reviewNotes.size() == 2);

	bool hasCitationQuality = false;
	bool hasWorkflowCorrectness = false;
	bool hasLatencyThroughput = false;
	bool hasMultimodalCoherence = false;
	bool hasAssistantSafety = false;

	for (const auto & metric : suite.metrics) {
		hasCitationQuality = hasCitationQuality || metric.id == "citation_quality";
		hasWorkflowCorrectness = hasWorkflowCorrectness || metric.id == "workflow_correctness";
		hasLatencyThroughput = hasLatencyThroughput || metric.id == "latency_throughput";
		hasMultimodalCoherence = hasMultimodalCoherence || metric.id == "multimodal_coherence";
		hasAssistantSafety = hasAssistantSafety || metric.id == "assistant_safety";
		REQUIRE_FALSE(metric.category.empty());
		REQUIRE_FALSE(metric.description.empty());
		REQUIRE_FALSE(metric.target.empty());
		REQUIRE(metric.threshold > 0.0);
		REQUIRE_FALSE(metric.evidenceRefs.empty());
	}

	REQUIRE(hasCitationQuality);
	REQUIRE(hasWorkflowCorrectness);
	REQUIRE(hasLatencyThroughput);
	REQUIRE(hasMultimodalCoherence);
	REQUIRE(hasAssistantSafety);

	for (const auto & evalCase : suite.cases) {
		REQUIRE_FALSE(evalCase.id.empty());
		REQUIRE_FALSE(evalCase.title.empty());
		REQUIRE_FALSE(evalCase.evaluationType.empty());
		REQUIRE_FALSE(evalCase.sourceRef.empty());
		REQUIRE_FALSE(evalCase.expectedBehavior.empty());
		REQUIRE_FALSE(evalCase.requiredSignals.empty());
	}
}

TEST_CASE("Trust evaluation suite serializes stable JSON keys", "[trust_evaluation]") {
	auto suite = ofxGgmlDefaultTrustEvaluationSuite();
	suite.metadata["owner"] = "companion-example";
	suite.metrics.front().metadata["source"] = "citation-search";
	suite.cases.front().metadata["priority"] = "high";
	suite.cases.front().addRequiredSignal("warnings");

	const auto json = suite.toJsonString();
	REQUIRE(json.find("\"schema_version\"") != std::string::npos);
	REQUIRE(json.find("ofxGgml.trust_evaluation_suite.v1") != std::string::npos);
	REQUIRE(json.find("\"suite_id\"") != std::string::npos);
	REQUIRE(json.find("\"manifest_ref\"") != std::string::npos);
	REQUIRE(json.find("\"assistant_team_ref\"") != std::string::npos);
	REQUIRE(json.find("\"metrics\"") != std::string::npos);
	REQUIRE(json.find("\"evidence_refs\"") != std::string::npos);
	REQUIRE(json.find("\"cases\"") != std::string::npos);
	REQUIRE(json.find("\"evaluation_type\"") != std::string::npos);
	REQUIRE(json.find("\"required_signals\"") != std::string::npos);
	REQUIRE(json.find("\"approval_rules\"") != std::string::npos);
	REQUIRE(json.find("\"review_notes\"") != std::string::npos);
	REQUIRE(json.find("warnings") != std::string::npos);
	REQUIRE(json.find("companion-example") != std::string::npos);
}

TEST_CASE("Trust evaluation suite ignores empty convenience entries", "[trust_evaluation]") {
	ofxGgmlTrustEvaluationMetric metric;
	metric.addEvidenceRef("");

	ofxGgmlTrustEvaluationCase evalCase;
	evalCase.addRequiredSignal("");

	ofxGgmlTrustEvaluationSuite suite;
	suite.addApprovalRule("");
	suite.addReviewNote("");
	suite.addMetric(metric);
	suite.addCase(evalCase);

	const auto json = suite.toJsonString();
	REQUIRE(json.find("\"evidence_refs\":[]") != std::string::npos);
	REQUIRE(json.find("\"required_signals\":[]") != std::string::npos);
	REQUIRE(json.find("\"approval_rules\":[]") != std::string::npos);
	REQUIRE(json.find("\"review_notes\":[]") != std::string::npos);
}
