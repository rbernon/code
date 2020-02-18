ifneq ($(V),1)
.SILENT:
endif
MAKEFLAGS += --no-print-directory


bin:
	install -m0755 -D bin/git-fip $(HOME)/.local/bin/git-fip
	install -m0755 -D bin/git-lmb $(HOME)/.local/bin/git-lmb
	install -m0755 -D bin/git-pab $(HOME)/.local/bin/git-pab
	install -m0755 -D bin/git-rab $(HOME)/.local/bin/git-rab
	install -m0644 -D bin/git-fip.completion.bash $(HOME)/.bash/completion/available/git-fip.completion.bash
	install -m0644 -D bin/git-lmb.completion.bash $(HOME)/.bash/completion/available/git-lmb.completion.bash
	install -m0644 -D bin/git-pab.completion.bash $(HOME)/.bash/completion/available/git-pab.completion.bash
	install -m0644 -D bin/git-rab.completion.bash $(HOME)/.bash/completion/available/git-rab.completion.bash
.PHONY: bin


build-proton/Makefile: $(shell mkdir -p build-proton)
	cd build-proton && ../proton/configure.sh \
	  --steam-runtime64=docker:rbernon/proton-amd64 \
	  --steam-runtime32=docker:rbernon/proton-i386 \
	  --steam-runtime=~/.steam/root/ubuntu12_32/steam-runtime \
	  --build-name=proton-local

proton: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 dist
.PHONY: proton
proton/wine: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 wine
.PHONY: proton/wine
proton/lsteamclient: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 lsteamclient
.PHONY: proton/lsteamclient
proton/install: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 install
.PHONY: proton/install


define make-source-rules
$(3)$(1)::
	-git clone --quiet $(2)/$(1) $(3)$(1) 2>/dev/null
	git -C $(3)$(1) fetch --all
	git -C $(3)$(1) checkout --quiet $($(1)_VERSION)
endef


VULKAN_SRCS = glslang \
              SPIRV-Headers \
              SPIRV-Tools \
              Vulkan-Headers \
              Vulkan-Loader \
              Vulkan-ValidationLayers

glslang_VERSION = origin/master
SPIRV-Headers_VERSION = origin/master
SPIRV-Tools_VERSION = origin/stable
Vulkan-Headers_VERSION = sdk-1.2.131.1
Vulkan-Loader_VERSION = sdk-1.2.131.1
Vulkan-ValidationLayers_VERSION = sdk-1.2.131.1

$(foreach t,$(VULKAN_SRCS),$(eval $(call make-source-rules,$(t),https://github.com/KhronosGroup,vulkan/)))

vulkan/CMakeLists.txt: $(patsubst %,vulkan/%,$(VULKAN_SRCS))
	echo "cmake_minimum_required(VERSION 3.13)" > vulkan/CMakeLists.txt
	echo "project(vulkan)" >> vulkan/CMakeLists.txt
	$(patsubst %,echo "add_subdirectory(%)" >>vulkan/CMakeLists.txt;,$(VULKAN_SRCS))

vulkan: vulkan/CMakeLists.txt
	cmake -Bbuild-$@ -H$@ \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DBUILD_LAYER_SUPPORT_FILES=ON \
	  -DCMAKE_CXX_FLAGS="-fsanitize=undefined" \
	  -DCMAKE_C_FLAGS="-fsanitize=undefined"
	$(MAKE) -C build-$@ install
.PHONY: vulkan


Vulkan-Tools_VERSION = sdk-1.2.131.1

$(eval $(call make-source-rules,Vulkan-Tools,https://github.com/KhronosGroup,vulkan/))

vulkan-tools: vulkan/Vulkan-Tools
	cmake -Bbuild-$@ -Hvulkan/Vulkan-Tools \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DVulkan_LIBRARY=$(HOME)/.local/lib/libvulkan.so \
	  -DVulkan_INCLUDE_DIR=$(HOME)/.local/include \
	  -DVULKAN_HEADERS_INSTALL_DIR=$(HOME)/.local/include \
	  -DVULKAN_LOADER_INSTALL_DIR=$(HOME)/.local \
	  -DVULKAN_VALIDATIONLAYERS_INSTALL_DIR=$(HOME)/.local \
	  -DCMAKE_INSTALL_SYSCONFDIR=share \
	  -DCMAKE_CXX_FLAGS="-fsanitize=undefined" \
	  -DCMAKE_C_FLAGS="-fsanitize=undefined"
	$(MAKE) -C build-$@ install
.PHONY: vulkan-tools


renderdoc_VERSION = origin/v1.x

$(eval $(call make-source-rules,renderdoc,https://github.com/baldurk,))

renderdoc::
	cmake -Bbuild-$@ -H$@ \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DVULKAN_LAYER_FOLDER=$(HOME)/.local/share/vulkan/implicit_layer.d \
	  -DCMAKE_CXX_FLAGS="-fsanitize=undefined" \
	  -DCMAKE_C_FLAGS="-fsanitize=undefined"
	$(MAKE) -C build-$@ install
