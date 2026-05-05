#pragma once

#include "ModelPresets.h"

#include <array>

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

const std::array<GuiModeDescriptor, 12> & defaultGuiModeDescriptors();
const std::array<GuiModeDescriptor, 3> & advancedGuiModeDescriptors();
const GuiModeDescriptor & guiModeDescriptor(AiMode mode);
bool isAdvancedGuiMode(AiMode mode);
