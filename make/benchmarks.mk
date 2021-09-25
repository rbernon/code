include make/common.mk

CMAKE_SYSTEM_NAME_linux-gnu = Linux
CMAKE_SYSTEM_NAME_w64-mingw32 = Windows

define benchmarks-build
benchmarks: benchmarks-$(1)-$(2)
benchmarks-$(1)-$(2): SHELL := $(SHELL_$(1))
benchmarks-$(1)-$(2):
	cmake -Bbuild-benchmarks/$(1)-$(2) -Hbenchmarks \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_C_COMPILER=$(1)-$(2)-gcc \
	  -DCMAKE_CXX_COMPILER=$(1)-$(2)-g++ \
	  -DCMAKE_SYSTEM_NAME=$(CMAKE_SYSTEM_NAME_$(2)) \
	  -DCMAKE_PREFIX_PATH=$(HOME)/.local/lib/$(1)-$(2)/cmake/ \
	&& $(MAKE) -j$(shell nproc) -C build-benchmarks/$(1)-$(2)
.PHONY: benchmarks-$(1)-$(2)
endef

$(eval $(call benchmarks-build,i686,linux-gnu))
$(eval $(call benchmarks-build,x86_64,linux-gnu))
$(eval $(call benchmarks-build,i686,w64-mingw32))
$(eval $(call benchmarks-build,x86_64,w64-mingw32))
