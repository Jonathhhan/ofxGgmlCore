#pragma once

#include "ModelPresets.h"

#include <array>
#include <cstddef>

enum class GuiModeTier {
	Stable,
	Advanced
};

struct GuiModeDescriptor {
	AiMode mode;
	const char * label;
	const char * summary;
	GuiModeTier tier;
};

constexpr std::size_t kDefaultGuiModeDescriptorCount = 12;
constexpr std::size_t kAdvancedGuiModeDescriptorCount = 3;

const std::array<GuiModeDescriptor, kDefaultGuiModeDescriptorCount> & defaultGuiModeDescriptors();
const std::array<GuiModeDescriptor, kAdvancedGuiModeDescriptorCount> & advancedGuiModeDescriptors();
const GuiModeDescriptor & guiModeDescriptor(AiMode mode);
bool isAdvancedGuiMode(AiMode mode);
