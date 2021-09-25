include make/common.mk

# CMAKE_SYSTEM_NAME_linux-gnu = Linux
CMAKE_SYSTEM_NAME_w64-mingw32 = Windows
CMAKE_C_FLAGS_w64-mingw32 = -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00 -Wl,--add-stdcall-alias
CMAKE_CXX_FLAGS_w64-mingw32 = -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00 -Wl,--add-stdcall-alias

define vulkan-build
vulkan: vulkan-$(1)-$(2)
vulkan-$(1)-$(2): SHELL := $(SHELL_$(1))
vulkan-$(1)-$(2):
	cmake -B/tmp/build-vulkan -Hvulkan \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DCMAKE_C_COMPILER=$(1)-$(2)-gcc \
	  -DCMAKE_CXX_COMPILER=$(1)-$(2)-g++ \
	  -DCMAKE_C_FLAGS="$(CMAKE_C_FLAGS_$(2))" \
	  -DCMAKE_CXX_FLAGS="$(CMAKE_CXX_FLAGS_$(2))" \
	  $(if $(CMAKE_SYSTEM_NAME_$(2)),-DCMAKE_SYSTEM_NAME=$(CMAKE_SYSTEM_NAME_$(2)),) \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DCMAKE_INSTALL_LIBDIR=lib/$(1)-$(2) \
	  -DCMAKE_INSTALL_BINDIR=$(1)-$(2)/bin \
	  -DBUILD_LAYER_SUPPORT_FILES=ON \
	&& $(MAKE) -j$(shell nproc) -C /tmp/build-vulkan install VERBOSE=1
.PHONY: vulkan-$(1)-$(2)
endef

$(eval $(call vulkan-build,i686,w64-mingw32))
$(eval $(call vulkan-build,x86_64,w64-mingw32))
$(eval $(call vulkan-build,i686,linux-gnu))
$(eval $(call vulkan-build,x86_64,linux-gnu))

# VULKAN_SRCS = glslang \
#               SPIRV-Headers \
#               SPIRV-Tools \
#               Vulkan-Headers \
#               Vulkan-Loader \
#               Vulkan-ValidationLayers

# glslang_VERSION = origin/master
# SPIRV-Headers_VERSION = origin/master
# SPIRV-Tools_VERSION = origin/stable
# Vulkan-Headers_VERSION = v1.2.151
# Vulkan-Loader_VERSION = v1.2.151
# Vulkan-ValidationLayers_VERSION = v1.2.151

# $(foreach t,$(VULKAN_SRCS),$(eval $(call make-source-rules,$(t),https://github.com/KhronosGroup,vulkan/)))

# vulkan/CMakeLists.txt: $(patsubst %,vulkan/%,$(VULKAN_SRCS))
# 	echo "cmake_minimum_required(VERSION 3.13)" > vulkan/CMakeLists.txt
# 	echo "project(vulkan)" >> vulkan/CMakeLists.txt
# 	$(patsubst %,echo "add_subdirectory(%)" >>vulkan/CMakeLists.txt;,$(VULKAN_SRCS))

# .PHONY: vulkan
