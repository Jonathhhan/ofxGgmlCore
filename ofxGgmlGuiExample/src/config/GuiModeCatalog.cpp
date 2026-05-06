#include "GuiModeCatalog.h"

#include <algorithm>

namespace {
	constexpr GuiModeDescriptor kFallbackModeDescriptor = {
		AiMode::Chat,
		"Chat",
		"General local text assistant.",
		GuiModeTier::Stable
	};

	constexpr std::array<GuiModeDescriptor, kDefaultGuiModeDescriptorCount> kDefaultGuiModes = {{
		{AiMode::Easy, "Easy", "Guided setup and simple addon onboarding.", GuiModeTier::Stable},
		{AiMode::Chat, "Chat", "General local text assistant.", GuiModeTier::Stable},
		{AiMode::Script, "Script", "Coding assistant with simple and advanced layouts.", GuiModeTier::Stable},
		{AiMode::Summarize, "Summarize", "Condense pasted text or local context.", GuiModeTier::Stable},
		{AiMode::Write, "Write", "Draft and rewrite creative text.", GuiModeTier::Stable},
		{AiMode::Translate, "Translate", "Translate text with selectable target languages.", GuiModeTier::Stable},
		{AiMode::Custom, "Custom", "Experiment with reusable system prompts.", GuiModeTier::Stable},
		{AiMode::Vision, "Vision", "Caption, inspect, and route image or video frames.", GuiModeTier::Stable},
		{AiMode::Speech, "Speech", "Transcribe microphone or file audio.", GuiModeTier::Stable},
		{AiMode::Tts, "TTS", "Preview local text-to-speech voices.", GuiModeTier::Stable},
		{AiMode::Diffusion, "Image", "Generate and transform images with diffusion profiles.", GuiModeTier::Stable},
		{AiMode::Clip, "CLIP", "Search and compare image/text embeddings.", GuiModeTier::Stable}
	}};

	constexpr std::array<GuiModeDescriptor, kAdvancedGuiModeDescriptorCount> kAdvancedGuiModes = {{
		{AiMode::VideoEssay, "Video Essay", "Companion workflow for structured video essays.", GuiModeTier::Advanced},
		{AiMode::LongVideo, "Video", "Long-form planning and montage workflow experiments.", GuiModeTier::Advanced},
		{AiMode::MilkDrop, "MilkDrop", "Audio-reactive visualization companion workflow.", GuiModeTier::Advanced}
	}};

	template <size_t N>
	const GuiModeDescriptor * findModeDescriptor(
		const std::array<GuiModeDescriptor, N> & descriptors,
		AiMode mode) {
		const auto it = std::find_if(
			descriptors.begin(),
			descriptors.end(),
			[mode](const GuiModeDescriptor & descriptor) {
				return descriptor.mode == mode;
			});
		return it == descriptors.end() ? nullptr : &(*it);
	}
}

const std::array<GuiModeDescriptor, kDefaultGuiModeDescriptorCount> & defaultGuiModeDescriptors() {
	return kDefaultGuiModes;
}

const std::array<GuiModeDescriptor, kAdvancedGuiModeDescriptorCount> & advancedGuiModeDescriptors() {
	return kAdvancedGuiModes;
}

const GuiModeDescriptor & guiModeDescriptor(AiMode mode) {
	if (const GuiModeDescriptor * descriptor = findModeDescriptor(kDefaultGuiModes, mode)) {
		return *descriptor;
	}
	if (const GuiModeDescriptor * descriptor = findModeDescriptor(kAdvancedGuiModes, mode)) {
		return *descriptor;
	}
	return kFallbackModeDescriptor;
}

bool isAdvancedGuiMode(AiMode mode) {
	return findModeDescriptor(kAdvancedGuiModes, mode) != nullptr;
}
