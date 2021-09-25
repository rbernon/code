
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
