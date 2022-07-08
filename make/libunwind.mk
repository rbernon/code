include make/common.mk

define libunwind-build
libunwind: libunwind-$(1)
libunwind-$(1): private SHELL := $(SHELL_$(1))
libunwind-$(1): build-libunwind/$(1)/Makefile
	$$(MAKE) -j$$(J) -C build-libunwind/$(1) install

build-libunwind/$(1)/Makefile: private SHELL := $(SHELL_$(1))
build-libunwind/$(1)/Makefile: $(shell mkdir -p build-libunwind/$(1))
build-libunwind/$(1)/Makefile: libunwind/configure
	cd build-libunwind/$(1) && ../../libunwind/configure --prefix=$(HOME)/.local --enable-debug
.PHONY: libunwind-$(1)
endef

libunwind/configure: libunwind/configure.ac
	cd libunwind && autoreconf -fi

# $(eval $(call libunwind-build,i686,linux-gnu))
$(eval $(call libunwind-build,x86_64,linux-gnu))
