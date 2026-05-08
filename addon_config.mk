meta:
	ADDON_NAME = ofxGgml
	ADDON_DESCRIPTION = Planned openFrameworks addon for ggml runtime, tensors, graphs, and local inference layers
	ADDON_AUTHOR = Jonathan Frank
	ADDON_TAGS = "ggml,ai,tensor,compute,inference"
	ADDON_URL = https://github.com/Jonathhhan/ofxGgml

common:
	ADDON_INCLUDES += src
	ADDON_INCLUDES += libs/ggml/include
	ADDON_CFLAGS += -DGGML_MAX_NAME=128
	ADDON_SOURCES_EXCLUDE += build/%
	ADDON_SOURCES_EXCLUDE += libs/ggml/.source/%
	ADDON_SOURCES_EXCLUDE += libs/ggml/build/%
	ADDON_INCLUDES_EXCLUDE += build/%
	ADDON_INCLUDES_EXCLUDE += libs/ggml/.source/%
	ADDON_INCLUDES_EXCLUDE += libs/ggml/build/%

vs:
	ADDON_LIBS += libs/ggml/lib/ggml.lib
	ADDON_LIBS += libs/ggml/lib/ggml-base.lib
	ADDON_LIBS += libs/ggml/lib/ggml-cpu.lib

linux64:
	ADDON_LIBS += libs/ggml/lib/libggml.a
	ADDON_LIBS += libs/ggml/lib/libggml-base.a
	ADDON_LIBS += libs/ggml/lib/libggml-cpu.a
	ADDON_LDFLAGS += -lpthread -ldl

osx:
	ADDON_LIBS += libs/ggml/lib/libggml.a
	ADDON_LIBS += libs/ggml/lib/libggml-base.a
	ADDON_LIBS += libs/ggml/lib/libggml-cpu.a
	ADDON_FRAMEWORKS += Accelerate
