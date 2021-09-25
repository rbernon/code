include make/common.mk

CMAKE_SYSTEM_NAME_linux-gnu = Linux
CMAKE_SYSTEM_NAME_w64-mingw32 = Windows

define nlopt-build
nlopt: nlopt-$(1)-$(2)
nlopt-$(1)-$(2): SHELL := $(SHELL_$(1))
nlopt-$(1)-$(2):
	cmake -Bbuild-nlopt/$(1)-$(2) -Hnlopt \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_C_COMPILER=$(1)-$(2)-gcc \
	  -DCMAKE_CXX_COMPILER=$(1)-$(2)-g++ \
	  -DCMAKE_SYSTEM_NAME=$(CMAKE_SYSTEM_NAME_$(2)) \
	  -DCMAKE_PREFIX_PATH=$(HOME)/.local/lib/$(1)-$(2)/cmake/ \
	  -DBUILD_SHARED_LIBS=OFF \
	&& $(MAKE) -j$(shell nproc) -C build-nlopt/$(1)-$(2)
.PHONY: nlopt-$(1)-$(2)
endef

$(eval $(call nlopt-build,i686,linux-gnu))
$(eval $(call nlopt-build,x86_64,linux-gnu))
$(eval $(call nlopt-build,i686,w64-mingw32))
$(eval $(call nlopt-build,x86_64,w64-mingw32))
