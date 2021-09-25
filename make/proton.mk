TOP := $(abspath $(PWD))
SRC := $(abspath ../$(PROTON))
BUILD := $(notdir $(PWD))

CCACHE_BASEDIR := $(SRC)
CCACHE_HASHDIR := true
CCACHE_COMPRESS := true

CC := gcc
CXX := g++

CC64 := x86_64-linux-gnu-$(CC)
CC32 := i686-linux-gnu-$(CC)
CXX32 := $(CC32:$(CC)=$(CXX))
CXX64 := $(CC64:$(CC)=$(CXX))
CROSS_CC64 := $(CC64:%-linux-gnu-$(CC)=%-w64-mingw32-$(CC))
CROSS_CC32 := $(CC32:%-linux-gnu-$(CC)=%-w64-mingw32-$(CC))

CMAKE = cmake
MESON = meson
NINJA = ninja

# silent/verbose flags all turned on with V=1
ifneq ($(V),1)
.SILENT:
--quiet? := --quiet
>/dev/null? := >/dev/null
else
--verbose? := --verbose
endif

DOCKER_IMAGE_32 := steam-proton-dev32
DOCKER_IMAGE_64 := steam-proton-dev

DOCKER_SHELL = docker run --rm --init --privileged --cap-add=SYS_ADMIN --security-opt apparmor:unconfined \
                 -v $(HOME):$(HOME) -v /tmp:/tmp \
                 -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro  -v /etc/shadow:/etc/shadow:ro \
                 -v $(HOME)/Code/build-proton-test/host-i686:/opt/i686-w64-mingw32 \
                 -v $(HOME)/Code/build-proton-test/host-x86_64:/opt/x86_64-w64-mingw32 \
                 -v $(CURDIR)/dist-bison/usr/share/bison:/usr/share/bison \
                 $(foreach t,$(TARGETS_HOST),-v $(CURDIR)/dist-$(t)/usr:/opt/$(t)) \
                 -w $(CURDIR) -e HOME -e PR_ARCH=$(PR_ARCH) \
                 -e PATH=$(foreach t,$(TARGETS_HOST),/opt/$(t)/bin:):$(PATH):/opt/i686-w64-mingw32/bin:/opt/x86_64-w64-mingw32/bin \
                 -u $(shell id -u):$(shell id -g) -h $(shell hostname) \
                 -e MAKEFLAGS -e MAKELEVEL \
                 $(DOCKER_OPTS) \
                 $(DOCKER_IMAGE_$(PR_ARCH)) /dev/init -sg -- /bin/bash
HOST_SHELL = env PR_ARCH=$(PR_ARCH) $(SHELL)

all:

ifeq ($(PR_ARCH),)
all: all-host all-64 all-32
.PHONY: $(MAKECMDGOALS) all any-host all-host any-64 all-64 any-32 all-32

$(filter %-host,$(MAKECMDGOALS)): any-host
$(filter %-64,$(MAKECMDGOALS)): any-64
$(filter %-32,$(MAKECMDGOALS)): any-32

any-host: private PR_ARCH := host
any-host: private SHELL := $(HOST_SHELL)
any-host:
	$(MAKE) $(MFLAGS) -C $(CURDIR) --no-print-directory --no-builtin-rules $(patsubst %-host,%,$(filter %-host,$(MAKECMDGOALS)))

all-host: private PR_ARCH := host
all-host: private SHELL := $(HOST_SHELL)
all-host:
	$(MAKE) $(MFLAGS) -C $(CURDIR) --no-print-directory --no-builtin-rules

any-64: private PR_ARCH := 64
any-64: private SHELL := $(DOCKER_SHELL)
any-64: all-host
	$(MAKE) $(MFLAGS) -C $(CURDIR) --no-print-directory --no-builtin-rules $(patsubst %-64,%,$(filter %-64,$(MAKECMDGOALS)))

all-64: private PR_ARCH := 64
all-64: private SHELL := $(DOCKER_SHELL)
all-64: all-host
	$(MAKE) $(MFLAGS) -C $(CURDIR) --no-print-directory --no-builtin-rules

any-32: private PR_ARCH := 32
any-32: private SHELL := $(DOCKER_SHELL)
any-32: all-host $(filter %-64,$(MAKECMDGOALS))
	$(MAKE) $(MFLAGS) -C $(CURDIR) --no-print-directory --no-builtin-rules $(patsubst %-32,%,$(filter %-32,$(MAKECMDGOALS)))

all-32: private PR_ARCH := 32
all-32: private SHELL := $(DOCKER_SHELL)
all-32: all-host all-64
	$(MAKE) $(MFLAGS) -C $(CURDIR) --no-print-directory --no-builtin-rules
endif

toupper = $(shell echo $(1) | tr '[:lower:]-' '[:upper:]_')
tolower = $(shell echo $(1) | tr '[:upper:]_' '[:lower:]-')

arch-suffix = $(call toupper,$(PR_ARCH))
arch-append = $$($(1)_$(2)) $$($(1)_$(arch-suffix)_$(2))
arch-prepend = $$($(1)_$(arch-suffix)_$(2)) $$($(1)_$(2))
arch-override = $$(if $$($(1)_$(arch-suffix)_$(2)),$$($(1)_$(arch-suffix)_$(2)),$$($(1)_$(2)))

define create-generic-rules
$(2)_FINAL_DEPS := $(call arch-append,$(2),DEPS)

$(2)_FINAL_CONFIGURE_ENV = $(call arch-append,$(2),CONFIGURE_ENV)
$(2)_FINAL_CONFIGURE_OPTS = $(call arch-append,$(2),CONFIGURE_OPTS)
$(2)_FINAL_CONFIGURE_SRC = $(call arch-override,$(2),CONFIGURE_SRC)
$(2)_FINAL_CONFIGURE_CMD = $(call arch-override,$(2),CONFIGURE_CMD)

$(2)_FINAL_BUILD_ENV = $(call arch-append,$(2),BUILD_ENV)
$(2)_FINAL_BUILD_OPTS = $(call arch-append,$(2),BUILD_OPTS)
$(2)_FINAL_BUILD_SRC = $(call arch-override,$(2),BUILD_SRC)
$(2)_FINAL_BUILD_CMD = $(call arch-override,$(2),BUILD_CMD)

$(2)_FINAL_INSTALL_ENV = $(call arch-append,$(2),INSTALL_ENV)
$(2)_FINAL_INSTALL_OPTS = $(call arch-append,$(2),INSTALL_OPTS)
$(2)_FINAL_INSTALL_SRC = $(call arch-override,$(2),INSTALL_SRC)
$(2)_FINAL_INSTALL_CMD = $(call arch-override,$(2),INSTALL_CMD)

obj-$(1)-$(PR_ARCH): | $$($(2)_FINAL_DEPS)
	mkdir -p $$@
obj-$(1)-$(PR_ARCH)/.step-configure: $$($(2)_FINAL_CONFIGURE_SRC) obj-$(1)-$(PR_ARCH)
	+cd "$$(@D)" && env $$($(2)_FINAL_CONFIGURE_ENV) $$($(2)_FINAL_CONFIGURE_CMD)
	touch $$@
obj-$(1)-$(PR_ARCH)/.step-build: $$($(2)_FINAL_BUILD_SRC) obj-$(1)-$(PR_ARCH)/.step-configure
	+cd "$$(@D)" && env $$($(2)_FINAL_BUILD_ENV) $$($(2)_FINAL_BUILD_CMD)
	touch $$@
obj-$(1)-$(PR_ARCH)/.step-install: $$($(2)_FINAL_INSTALL_SRC) obj-$(1)-$(PR_ARCH)/.step-build
	+cd "$$(@D)" && env $$($(2)_FINAL_INSTALL_ENV) $$($(2)_FINAL_INSTALL_CMD)
	touch $$@

$(1)-clean:
	$$($(2)_DISTCLEAN_CMD)
	rm obj-$(1)-$(PR_ARCH) -rf
$(1)-clean-for-reconfigure: $(1)-clean-for-rebuild
	rm obj-$(1)-$(PR_ARCH)/.step-configure -f
$(1)-clean-for-rebuild: $(1)-clean-for-reinstall
	rm obj-$(1)-$(PR_ARCH)/.step-build -f
$(1)-clean-for-reinstall:
	rm obj-$(1)-$(PR_ARCH)/.step-install -f

$(1)-configure: obj-$(1)-$(PR_ARCH)/.step-configure
$(1)-build: obj-$(1)-$(PR_ARCH)/.step-build
$(1)-install: obj-$(1)-$(PR_ARCH)/.step-install

$(1)-reconfigure: $(1)-clean-for-reconfigure $(1)
$(1)-rebuild: $(1)-clean-for-rebuild $(1)
$(1)-reinstall: $(1)-clean-for-reinstall $(1)

$(1): $(1)-install
endef

define create-makefile-rules
$(2)_BUILD_SRC = obj-$(1)-$(PR_ARCH)/Makefile
$(2)_BUILD_CMD = $$(MAKE) MAKEFLAGS="$$(MAKEFLAGS)" $$($(2)_BUILD_OPTS) $$($(2)_$(call toupper,$(PR_ARCH))_BUILD_OPTS)

$(2)_INSTALL_SRC = obj-$(1)-$(PR_ARCH)/Makefile
$(2)_INSTALL_CMD = $$(MAKE) MAKEFLAGS="$$(MAKEFLAGS)" install DESTDIR=$$(TOP)/dist-$(1) $$($(2)_INSTALL_OPTS)

obj-$(1)-$(PR_ARCH)/Makefile: obj-$(1)-$(PR_ARCH)/.step-configure

$(call create-generic-rules,$(1),$(2))
endef

define create-ninja-rules
$(2)_BUILD_SRC = obj-$(1)-$(PR_ARCH)/build.ninja
$(2)_BUILD_CMD = $$(NINJA) $$(--verbose?) $$($(2)_BUILD_OPTS) $$($(2)_$(call toupper,$(PR_ARCH))_BUILD_OPTS)

$(2)_INSTALL_SRC = obj-$(1)-$(PR_ARCH)/build.ninja
$(2)_INSTALL_CMD = DESTDIR=$$(TOP)/dist-$(1) $$(NINJA) $$(--verbose?) install $$($(2)_INSTALL_OPTS)

obj-$(1)-$(PR_ARCH)/build.ninja: obj-$(1)-$(PR_ARCH)/.step-configure

$(call create-generic-rules,$(1),$(2))
endef

define create-configure-rules
$(2)_CONFIGURE_SRC = $$($(2)_SRC)/configure
$(2)_CONFIGURE_CMD = "$$<" $$(>/dev/null?) --prefix=/usr $$($(2)_FINAL_CONFIGURE_OPTS)

$(call create-makefile-rules,$(1),$(2))
endef

define create-autoconf-rules
$(2)_CONFIGURE_SRC = $$($(2)_SRC)/configure
$(2)_CONFIGURE_CMD = "$$<" $$(--quiet?) --prefix=/usr --cache-file="$$(HOME)/.cache/autoconf/$$(BUILD)-$(1)-$(PR_ARCH)" $$($(2)_FINAL_CONFIGURE_OPTS)

$(2)_DISTCLEAN_CMD = rm -rf "$$(HOME)/.cache/autoconf/$$(BUILD)-$(1)"
$$($(2)_SRC)/configure:: $$($(2)_SRC)/configure.ac
	cd "$$($(2)_SRC)" && autoreconf -fi

$(call create-makefile-rules,$(1),$(2))
endef

define create-cmake-rules
$(2)_CONFIGURE_SRC = $$($(2)_SRC)/CMakeLists.txt
$(2)_CONFIGURE_CMD = $$(CMAKE) "$$(<D)" -DCMAKE_INSTALL_PREFIX=/usr $$($(2)_FINAL_CONFIGURE_OPTS)

$(call create-makefile-rules,$(1),$(2))
endef

define create-meson-rules
$(2)_CONFIGURE_SRC = $$($(2)_SRC)/meson.build
$(2)_CONFIGURE_CMD = $$(MESON) "$$(<D)" --prefix="/" --buildtype=release $$($(2)_FINAL_CONFIGURE_OPTS)

$(call create-ninja-rules,$(1),$(2))
endef

define create-target-rules
ifneq ($(PR_ARCH),)
ifneq ($(PR_ARCH),host)
$(call create-$(1)-rules,$(call tolower,$(2)),$(2))
all: $(call tolower,$(2))
endif
TARGETS_$(call toupper,$(PR_ARCH)) += $(call tolower,$(2))
endif
endef

define create-host-rules
ifneq ($(PR_ARCH),)
ifeq ($(PR_ARCH),host)
$(call create-$(1)-rules,$(call tolower,$(2)),$(2))
all: $(call tolower,$(2))
endif
TARGETS_$(call toupper,$(PR_ARCH)) += $(call tolower,$(2))
endif
endef

.PHONY: all clean requests requests-reset
# all: dxvk d9vk wine
clean:
	rm -rf wine32 wine64

# dxvk: | wine
# d9vk: | dxvk

$(TOP)/bison-%.tar.xz:
	wget https://ftpmirror.gnu.org/bison/$(@F) -P "$(@D)"
$(TOP)/bison-%/configure.ac: bison-%.tar.xz
	tar xf $< $(--verbose?)
	touch $@


GLSLANG_SRC := $(SRC)/../vulkan/glslang
GLSLANG_CONFIGURE_ENV = CFLAGS=-static CXXFLAGS=-static LDFLAGS="-s -static"
$(eval $(call create-host-rules,cmake,GLSLANG))

BISON_SRC := $(SRC)/contrib/bison-3.3.2
BISON_CONFIGURE_ENV = CFLAGS=-static CXXFLAGS=-static LDFLAGS="-s -static"
$(eval $(call create-host-rules,autoconf,BISON))

CMAKE_SRC := $(SRC)/cmake
CMAKE_CONFIGURE_OPTS = -- -DBUILD_SHARED_LIBS=OFF -DBUILD_TESTING=OFF -DBUILD_CursesDialog=OFF -DBUILD_QtDialog=OFF
CMAKE_CONFIGURE_ENV = CFLAGS=-static CXXFLAGS=-static LDFLAGS="-s -static -Wl,--start-group -lpthread -ldl"
$(eval $(call create-host-rules,configure,CMAKE))

WINE_SRC := $(SRC)/wine
WINE_HOST_CONFIGURE_ENV := CFLAGS=-static CXXFLAGS=-static LDFLAGS="-s -static"
WINE_HOST_CONFIGURE_OPTS := --enable-win64 --disable-win16 --disable-tests --without-x --without-freetype
WINE_HOST_BUILD_OPTS := tools tools/widl tools/winegcc
WINE_HOST_INSTALL_CMD := install -m 0755 -D -t $(TOP)/dist-wine-tools/usr/bin \
                            tools/widl/widl \
                            tools/winegcc/winegcc \
                            tools/winegcc/winecpp \
                            tools/winegcc/wineg++ \
                            $(SRC)/wine/tools/winemaker/winemaker
WINE_64_CONFIGURE_OPTS := --with-mingw --enable-win64
WINE_32_CONFIGURE_OPTS := --with-mingw --with-wine64="$(TOP)/obj-wine-64"
$(eval $(call create-host-rules,autoconf,WINE))
$(eval $(call create-target-rules,autoconf,WINE))

VKD3D_SRC := $(SRC)/vkd3d
$(eval $(call create-target-rules,autoconf,VKD3D))

DXVK_SRC := $(SRC)/dxvk
DXVK_CONFIGURE_OPTS := --cross-file "$(DXVK_SRC)/build-win$(PR_ARCH).txt"
$(eval $(call create-target-rules,meson,DXVK))

D9VK_SRC := $(SRC)/d9vk
D9VK_DEPS := dxvk
D9VK_CONFIGURE_OPTS := --cross-file "$(D9VK_SRC)/build-win$(PR_ARCH).txt" -Denable_dxgi=false -Denable_d3d10=false -Denable_d3d11=false
$(eval $(call create-target-rules,meson,D9VK))

RENDERDOC_SRC := $(SRC)/../renderdoc
RENDERDOC_CONFIGURE_OPTS := -DENABLE_XCB=OFF -DENABLE_QRENDERDOC=OFF -DENABLE_PYRENDERDOC=OFF
$(eval $(call create-target-rules,cmake,RENDERDOC))

make-requests:
	cd "$(SRC)/wine" && git checkout include/wine/server_protocol.h server/request.h server/trace.c && tools/make_requests

binutils-%.tar.gz:
	wget https://ftp.gnu.org/gnu/binutils/$(@F) -P "$(@D)"
binutils-%/configure: binutils-%.tar.gz
	tar xf $< $(--verbose?)
	touch $@

mingw-w64-v%.tar.bz2:
	wget https://sourceforge.net/projects/mingw-w64/files/mingw-w64/mingw-w64-release/$(@F) -P "$(@D)"
mingw-w64-v%/configure: mingw-w64-v%.tar.bz2
	tar xf $< $(--verbose?)
	touch $@
mingw-w64-v%/mingw-w64-headers/configure: mingw-w64-v%/configure
	touch $@
mingw-w64-v%/mingw-w64-crt/configure: mingw-w64-v%/configure
	touch $@
mingw-w64-v%/mingw-w64-libraries/winpthreads/configure: mingw-w64-v%/configure
	touch $@

isl-%.tar.bz2:
	wget http://isl.gforge.inria.fr/$(@F) -P "$(@D)"
isl-%/configure: isl-%.tar.bz2
	tar xf $< $(--verbose?)
	touch $@

gcc-%.tar.xz:
	wget https://ftp.gnu.org/gnu/gcc/gcc-$*/$(@F) -P "$(@D)"
gcc-%/configure: gcc-%.tar.xz
	tar xf $< $(--verbose?)
	touch $@

obj-mingw-binutils-%/.build: binutils-2.32/configure
	mkdir -p obj-mingw-binutils-$*
	cd "$(@D)" && env PATH="$(TOP)/host-$*/bin:$(PATH)" "$(TOP)/$<" -C $(--quiet?) \
	  --prefix=/ --target=$*-w64-mingw32 \
	  --disable-plugins --disable-shared --enable-static \
	  --disable-nls --disable-multilib --enable-lto
	$(MAKE) -C "obj-mingw-binutils-$*" MAKEINFO=true configure-host
	$(MAKE) -C "obj-mingw-binutils-$*" MAKEINFO=true LDFLAGS="-all-static"
	$(MAKE) -C "obj-mingw-binutils-$*" MAKEINFO=true install DESTDIR="$(TOP)/host-$*"
	touch $@

obj-mingw-headers-%/.build: mingw-w64-v6.0.0/mingw-w64-headers/configure | obj-mingw-binutils-%/.build
	mkdir -p obj-mingw-headers-$*
	cd "$(@D)" && env PATH="$(TOP)/host-$*/bin:$(PATH)" "$(TOP)/$<" -C $(--quiet?) \
	  --prefix=/$*-w64-mingw32/ --host=$*-w64-mingw32 \
	  --enable-sdk=all --enable-secure-api --enable-idl
	$(MAKE) -C "obj-mingw-headers-$*" MAKEINFO=true install DESTDIR="$(TOP)/host-$*"
	ln -sf $*-w64-mingw32 "$(TOP)/host-$*/mingw"
	touch $@

obj-mingw-gcc-%/.build: gcc-8.3.0/configure | obj-mingw-headers-%/.build
	mkdir -p obj-mingw-gcc-$*
	cd "$(@D)" && env PATH="$(TOP)/host-$*/bin:$(PATH)" "$(TOP)/$<" -C $(--quiet?) \
	  --prefix=/ --target=$*-w64-mingw32 \
	  --with-gnu-ld --with-gnu-as \
	  --enable-languages=c,c++ --disable-multilib --enable-threads=posix --enable-fully-dynamic-string \
	  --enable-libstdcxx-time=yes --enable-cloog-backend=isl \
	  --enable-lto --disable-sjlj-exceptions --with-dwarf2 \
	  --enable-static --enable-shared \
	  --with-system-zlib --with-system-gmp --with-system-mpfr --with-system-mpc \
	  --disable-nls --disable-multilib --enable-checking=release \
	  --with-sysroot --with-build-sysroot="$(TOP)/host-$*"
	$(MAKE) -C "obj-mingw-gcc-$*" MAKEINFO=true CFLAGS="-static --static" LDFLAGS="-s -static --static" all-gcc
	$(MAKE) -C "obj-mingw-gcc-$*" MAKEINFO=true CFLAGS="-static --static" LDFLAGS="-s -static --static" install-gcc DESTDIR="$(TOP)/host-$*"
	touch $@

obj-mingw-crt-%/.build: mingw-w64-v6.0.0/mingw-w64-crt/configure | obj-mingw-gcc-%/.build
	mkdir -p obj-mingw-crt-$*
	cd "$(@D)" && env PATH="$(TOP)/host-$*/bin:$(PATH)" CC=$*-w64-mingw32-gcc "$(TOP)/$<" -C $(--quiet?) \
	  --prefix=/$*-w64-mingw32/ --host=$*-w64-mingw32 \
	  --enable-wildcard
	$(MAKE) -C "obj-mingw-crt-$*" MAKEINFO=true
	$(MAKE) -C "obj-mingw-crt-$*" MAKEINFO=true install DESTDIR="$(TOP)/host-$*"
	touch $@

obj-mingw-winpthreads-%/.build: mingw-w64-v6.0.0/mingw-w64-libraries/winpthreads/configure | obj-mingw-crt-%/.build
	mkdir -p obj-mingw-winpthreads-$*
	cd "$(@D)" && env PATH="$(TOP)/host-$*/bin:$(PATH)" CC=$*-w64-mingw32-gcc "$(TOP)/$<" -C $(--quiet?) \
	  --prefix=/$*-w64-mingw32/ --host=$*-w64-mingw32
	$(MAKE) -C "obj-mingw-winpthreads-$*" MAKEINFO=true
	$(MAKE) -C "obj-mingw-winpthreads-$*" MAKEINFO=true install DESTDIR="$(TOP)/host-$*"
	touch $@

obj-mingw-gcc-%/.build-full: gcc-8.3.0/configure | obj-mingw-winpthreads-%/.build
	$(MAKE) -C "obj-mingw-gcc-$*" MAKEINFO=true CFLAGS="-static --static" LDFLAGS="-s -static --static"
	$(MAKE) -C "obj-mingw-gcc-$*" MAKEINFO=true CFLAGS="-static --static" LDFLAGS="-s -static --static" install DESTDIR="$(TOP)/host-$*"
	touch $@

mingw-x86_64: obj-mingw-binutils-x86_64/.build
mingw-x86_64: obj-mingw-headers-x86_64/.build
mingw-x86_64: obj-mingw-gcc-x86_64/.build
mingw-x86_64: obj-mingw-crt-x86_64/.build
mingw-x86_64: obj-mingw-winpthreads-x86_64/.build
mingw-x86_64: obj-mingw-gcc-x86_64/.build-full

mingw-i686: obj-mingw-binutils-i686/.build
mingw-i686: obj-mingw-headers-i686/.build
mingw-i686: obj-mingw-gcc-i686/.build
mingw-i686: obj-mingw-crt-i686/.build
mingw-i686: obj-mingw-winpthreads-i686/.build
mingw-i686: obj-mingw-gcc-i686/.build-full

all:


# Delete default rules. We don't use them. This saves a bit of time.
.SUFFIXES:
.SECONDARY:
