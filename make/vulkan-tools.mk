include make/common.mk

define vulkan-tools-build
vulkan-tools-$(1): SHELL := $(SHELL_$(1))
vulkan-tools-$(1):
	cmake -B/tmp/build-vulkan-tools -Hvulkan/Vulkan-Tools \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DCMAKE_INSTALL_LIBDIR=lib/$(1)-linux-gnu \
	  -DCMAKE_INSTALL_BINDIR=$(1)-linux-gnu/bin \
	  -DVulkan_LIBRARY=$(HOME)/.local/lib/$(1)-linux-gnu/libvulkan.so \
	  -DVulkan_INCLUDE_DIR=$(HOME)/.local/include \
	  -DVULKAN_HEADERS_INSTALL_DIR=$(HOME)/.local/include \
	  -DVULKAN_LOADER_INSTALL_DIR=$(HOME)/.local \
	&& $(MAKE) -j$(shell nproc) -C /tmp/build-vulkan-tools install
.PHONY: vulkan-tools-$(1)
endef

$(eval $(call vulkan-tools-build,i686))
$(eval $(call vulkan-tools-build,x86_64))

vulkan-tools: vulkan-tools-i686



# Vulkan-Tools_VERSION = sdk-1.2.131.1

# $(eval $(call make-source-rules,Vulkan-Tools,https://github.com/KhronosGroup,vulkan/))

# vulkan-tools: vulkan/Vulkan-Tools
# 	cmake -Bbuild-$@ -Hvulkan/Vulkan-Tools \
# 	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
# 	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
# 	  -DVulkan_LIBRARY=$(HOME)/.local/lib/libvulkan.so \
# 	  -DVulkan_INCLUDE_DIR=$(HOME)/.local/include \
# 	  -DVULKAN_HEADERS_INSTALL_DIR=$(HOME)/.local/include \
# 	  -DVULKAN_LOADER_INSTALL_DIR=$(HOME)/.local \
# 	  -DVULKAN_VALIDATIONLAYERS_INSTALL_DIR=$(HOME)/.local \
# 	  -DCMAKE_INSTALL_SYSCONFDIR=share \
# 	  -DCMAKE_CXX_FLAGS="-fsanitize=undefined" \
# 	  -DCMAKE_C_FLAGS="-fsanitize=undefined"
# 	$(MAKE) -C build-$@ install
# .PHONY: vulkan-tools

