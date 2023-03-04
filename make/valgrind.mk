include make/common.mk

define valgrind-build
valgrind: valgrind-$(1)
valgrind-$(1): build-valgrind/$(1)/Makefile
	$$(MAKE) -j$$(J) -C build-valgrind/$(1) install

build-valgrind/$(1)/Makefile: $(shell mkdir -p build-valgrind/$(1))
build-valgrind/$(1)/Makefile: valgrind/configure
	cd build-valgrind/$(1) && ../../valgrind/configure --prefix=$(HOME)/.local
.PHONY: valgrind-$(1)
endef

valgrind/configure: valgrind/configure.ac
	cd valgrind && autoreconf -fi

# $(eval $(call valgrind-build,i686,linux-gnu))
$(eval $(call valgrind-build,x86_64,linux-gnu))
