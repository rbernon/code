include make/common.mk

define mono-build
mono: libmono-$(1) mono-$(1)
libmono: libmono-$(1)
libmono-$(1): private SHELL := $(SHELL_proton)
libmono-$(1): build-mono/$(1)-lib/Makefile
	$$(MAKE) -j$$(J) -C build-mono/$(1)-lib

mono-$(1): private SHELL := $(SHELL_proton)
mono-$(1): build-mono/$(1)/Makefile
	env PATH="$(CURDIR)build-mono/x86_64/mono/mini:$(PATH)" \
	$$(MAKE) -j$$(J) -C build-mono/$(1) && \
	$$(MAKE) -j$$(J) -C build-mono/$(1) install

build-mono/$(1)/Makefile: private SHELL := $(SHELL_proton)
build-mono/$(1)/Makefile: $(shell mkdir -p build-mono/$(1))
build-mono/$(1)/Makefile: mono/configure
	cd mono && NOCONFIGURE=yes ./autogen.sh && \
	cd ../build-mono/$(1) && ../../mono/configure -C --prefix=$(HOME)/.local/mono/$(1) \
	  --with-tls=none \
	  --with-compiler-server=no \
	  --disable-boehm \

build-mono/$(1)-lib/Makefile: build-mono/$(1)/Makefile
build-mono/$(1)-lib/Makefile: private SHELL := $(SHELL_proton)
build-mono/$(1)-lib/Makefile: $(shell mkdir -p build-mono/$(1)-lib)
build-mono/$(1)-lib/Makefile: mono/configure
	cd build-mono/$(1)-lib && ../../mono/configure -C --prefix=$(HOME)/.local/mono/$(1) \
	  --with-profile4_x=no \
	  --with-tls=none \
	  --disable-mcs-build \
	  --disable-boehm \

#	  --enable-win32-dllmain=yes \
#	  --with-libgc-threads=win32 \
#	  mono_cv_clang=no \
#	  mono_feature_disable_cleanup=yes \

.PHONY: mono-$(1)
endef

mono/configure: mono/configure.ac
	cd mono && autoreconf -fi

# $(eval $(call mono-build,i686,linux-gnu))
$(eval $(call mono-build,x86_64,linux-gnu))
