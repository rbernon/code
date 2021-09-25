include make/common.mk

CMAKE_SYSTEM_NAME_linux-gnu = Linux
CMAKE_SYSTEM_NAME_w64-mingw32 = Windows

define dlib-build
dlib: dlib-$(1)-$(2)
dlib-$(1)-$(2): SHELL := $(SHELL_$(1))
dlib-$(1)-$(2):
	cmake -Bbuild-dlib/$(1)-$(2) -Hdlib/examples \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_C_COMPILER=$(1)-$(2)-gcc \
	  -DCMAKE_CXX_COMPILER=$(1)-$(2)-g++ \
	  -DCMAKE_SYSTEM_NAME=$(CMAKE_SYSTEM_NAME_$(2)) \
	  -DCMAKE_PREFIX_PATH=$(HOME)/.local/lib/$(1)-$(2)/cmake/ \
	  -DBUILD_SHARED_LIBS=OFF \
	&& $(MAKE) -j$(shell nproc) -C build-dlib/$(1)-$(2)
.PHONY: dlib-$(1)-$(2)
endef

$(eval $(call dlib-build,i686,linux-gnu))
$(eval $(call dlib-build,x86_64,linux-gnu))
$(eval $(call dlib-build,i686,w64-mingw32))
$(eval $(call dlib-build,x86_64,w64-mingw32))
