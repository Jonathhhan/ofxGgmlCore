#pragma once

/// Specialized workflows header for ofxGgml addon.
///
/// This header adds opt-in addon-tier research and planning workflows:
/// - Video planning and editing (beat planning, multi-scene scripts)
/// - Citation search (source-grounded research)
/// - Web crawling and RAG pipelines
/// - Media prompt translation
/// - Image search (reference gathering)
///
/// Montage planning, video essay, music generation, MilkDrop, AceStep, and
/// Holoscan bridge surfaces are companion/example-tier features. Include
/// ofxGgmlCompanionWorkflows.h, or define
/// OFXGGML_ENABLE_COMPANION_WORKFLOWS=1 before including ofxGgmlEasy.h, when
/// you intentionally opt into those boundaries.
///
/// Example usage:
///   #include "ofxGgmlWorkflows.h"
///
///   ofxGgmlEasy ai;
///   ai.configureText(textConfig);
///
///   // Use video planning workflow
///   auto plan = ai.planVideoEdit(
///     "City footage",
///     "Create a fast-paced social recap",
///     "Skyline, transit, crowds");

// Include modalities (which includes basic)
#include "ofxGgmlModalities.h"

// Video workflows
#include "inference/ofxGgmlVideoPlanner.h"
#include "inference/ofxGgmlLongVideoPlanner.h"

// Research and content workflows
#include "inference/ofxGgmlCitationSearch.h"
#include "inference/ofxGgmlWebCrawler.h"
#include "inference/ofxGgmlImageSearch.h"
#include "inference/ofxGgmlRAGPipeline.h"

// Music and creative workflows
#include "inference/ofxGgmlMediaPromptGenerator.h"
