meta:
	ADDON_NAME = ofxGgmlCore
	ADDON_DESCRIPTION = Core openFrameworks addon for ggml runtime, tensors, graphs, and local inference boundaries
	ADDON_AUTHOR = Jonathan Frank
	ADDON_TAGS = "ggml,ai,tensor,compute,inference"
	ADDON_URL = https://github.com/Jonathhhan/ofxGgmlCore

common:
	ADDON_INCLUDES = src
	ADDON_INCLUDES += libs/ggml/include
	ADDON_CFLAGS += -DGGML_MAX_NAME=128
	ADDON_SOURCES = src/compute/ofxGgmlGraph.cpp
	ADDON_SOURCES += src/compute/ofxGgmlTensor.cpp
	ADDON_SOURCES += src/core/ofxGgmlRuntime.cpp
	ADDON_SOURCES += src/inference/ofxGgmlEmbedding.cpp
	ADDON_SOURCES += src/inference/ofxGgmlSegmentationInference.cpp
	ADDON_SOURCES += src/inference/ofxGgmlTextGeneration.cpp
	ADDON_SOURCES += src/model/ofxGgmlModel.cpp
	ADDON_SOURCES_EXCLUDE = build/%
	ADDON_SOURCES_EXCLUDE += libs/ggml/.source/%
	ADDON_SOURCES_EXCLUDE += libs/ggml/build/%
	ADDON_SOURCES_EXCLUDE += libs/ggml/build-cuda/%
	ADDON_SOURCES_EXCLUDE += libs/ggml/build-native/%
	ADDON_SOURCES_EXCLUDE += libs/ggml/build-vulkan/%
	ADDON_SOURCES_EXCLUDE += libs/llama.cpp/.source/%
	ADDON_SOURCES_EXCLUDE += libs/llama.cpp/build/%
	ADDON_SOURCES_EXCLUDE += libs/llama.cpp/build-cuda/%
	ADDON_SOURCES_EXCLUDE += libs/llama.cpp/build-native/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/.git/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/sam3.cpp
	ADDON_SOURCES_EXCLUDE += libs/sam3/build/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/build-cuda/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/build-native/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/ggml/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/examples/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/media/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/scripts/%
	ADDON_SOURCES_EXCLUDE += libs/sam3/tests/%
	ADDON_INCLUDES_EXCLUDE = build/%
	ADDON_INCLUDES_EXCLUDE += libs/ggml/.source/%
	ADDON_INCLUDES_EXCLUDE += libs/ggml/build/%
	ADDON_INCLUDES_EXCLUDE += libs/ggml/build-cuda/%
	ADDON_INCLUDES_EXCLUDE += libs/ggml/build-native/%
	ADDON_INCLUDES_EXCLUDE += libs/ggml/build-vulkan/%
	ADDON_INCLUDES_EXCLUDE += libs/llama.cpp/.source/%
	ADDON_INCLUDES_EXCLUDE += libs/llama.cpp/build/%
	ADDON_INCLUDES_EXCLUDE += libs/llama.cpp/build-cuda/%
	ADDON_INCLUDES_EXCLUDE += libs/llama.cpp/build-native/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/.git/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/build/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/build-cuda/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/build-native/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/ggml/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/examples/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/media/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/scripts/%
	ADDON_INCLUDES_EXCLUDE += libs/sam3/tests/%

vs:
	# @OFXGGML_LIBS_START vs
	ADDON_CFLAGS += -DOFXGGML_WITH_CUDA
	ADDON_LIBS += libs/ggml/lib/ggml.lib
	ADDON_LIBS += libs/ggml/lib/ggml-base.lib
	ADDON_LIBS += libs/ggml/lib/ggml-cpu.lib
	ADDON_LIBS += libs/ggml/lib/ggml-cuda.lib
	ADDON_LIBS += Advapi32.lib
	ADDON_LIBS += $(CUDA_PATH)/lib/x64/cublas.lib
	ADDON_LIBS += $(CUDA_PATH)/lib/x64/cudart.lib
	ADDON_LIBS += $(CUDA_PATH)/lib/x64/cuda.lib
	# @OFXGGML_LIBS_END vs
	# @OFXGGML_SAM3_LIBS_START vs
	# SAM3 support moved to ofxGgmlSam.
	# @OFXGGML_SAM3_LIBS_END vs

linux64:
	# @OFXGGML_LIBS_START linux64
	ADDON_LIBS += libs/ggml/lib/libggml.a
	ADDON_LIBS += libs/ggml/lib/libggml-base.a
	ADDON_LIBS += libs/ggml/lib/libggml-cpu.a
	# @OFXGGML_LIBS_END linux64
	# @OFXGGML_SAM3_LIBS_START linux64
	# @OFXGGML_SAM3_LIBS_END linux64
	ADDON_LDFLAGS += -lpthread -ldl

osx:
	# @OFXGGML_LIBS_START osx
	ADDON_LIBS += libs/ggml/lib/libggml.a
	ADDON_LIBS += libs/ggml/lib/libggml-base.a
	ADDON_LIBS += libs/ggml/lib/libggml-cpu.a
	# @OFXGGML_LIBS_END osx
	# @OFXGGML_SAM3_LIBS_START osx
	# @OFXGGML_SAM3_LIBS_END osx
	ADDON_FRAMEWORKS += Accelerate
