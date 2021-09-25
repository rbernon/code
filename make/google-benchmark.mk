include make/common.mk

CMAKE_SYSTEM_NAME_linux-gnu = Linux
CMAKE_SYSTEM_NAME_w64-mingw32 = Windows

define google-benchmark-build
google-benchmark: google-benchmark-$(1)-$(2)
google-benchmark-$(1)-$(2): SHELL := $(SHELL_$(1))
google-benchmark-$(1)-$(2):
	cmake -B/tmp/build-google-benchmark -Hgoogle-benchmark \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DCMAKE_CXX_COMPILER=$(1)-$(2)-g++ \
	  -DCMAKE_SYSTEM_NAME=$(CMAKE_SYSTEM_NAME_$(2)) \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DCMAKE_INSTALL_LIBDIR=lib/$(1)-$(2) \
	  -DCMAKE_INSTALL_BINDIR=$(1)-$(2)/bin \
	  -DBENCHMARK_ENABLE_TESTING=FALSE \
	&& $(MAKE) -j$(shell nproc) -C /tmp/build-google-benchmark install
.PHONY: google-benchmark-$(1)-$(2)
endef

$(eval $(call google-benchmark-build,i686,linux-gnu))
$(eval $(call google-benchmark-build,x86_64,linux-gnu))
$(eval $(call google-benchmark-build,i686,w64-mingw32))
$(eval $(call google-benchmark-build,x86_64,w64-mingw32))
