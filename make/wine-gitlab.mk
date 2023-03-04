OBJ := $(abspath $(CURDIR))
BUILD := $(notdir $(OBJ))

include ../make/silent.mk
include ../make/utility.mk
include ../make/rules-source.mk

all: wine
.PHONY: all

J := $(shell nproc)
JFLAGS = -j$(J) $(filter -j%,$(MAKEFLAGS))

ifeq ($(MAKELEVEL),0)

DOCKER_SHELL = docker run --rm -e HOME -e USER -e USERID=$(shell id -u) -u $(shell id -u):$(shell id -g) \
                 -v $(CURDIR)/.home:$(HOME) -v $(HOME)/.ccache:$(HOME)/.ccache -v $(HOME)/.cache:$(HOME)/.cache \
                 -v $(WINE_SRC):$(WINE_SRC) -v $(OBJ):$(OBJ) -v $(OBJ)/../make:$(OBJ)/../make -w $(OBJ) \
								 -e MAKEFLAGS -e CCACHE_COMPILERCHECK=none \
                 -e WINE -e WINEDLLOVERRIDES -e WINEARCH -e WINEPREFIX -e WINESERVER -e WINETEST -e WINEDEBUG \
                 docker.io/rbernon/winehq:latest $(SHELL)
any: $(shell mkdir -p .home/.cache .home/.ccache .home/Code/build-wine)

WINE_SOURCE_ARGS = \
  --exclude configure \
  --exclude autom4te.cache \
  --exclude include/config.h.in \

WINE_SRC := $(abspath source)
$(eval $(call rules-source,wine,$(abspath $(WINE))))

any: private SHELL := $(DOCKER_SHELL)
any: wine-source
	+$(MAKE) -f $(firstword $(MAKEFILE_LIST)) $(MAKECMDGOALS) MAKELEVEL=1

wine test: any
%.ok %/tests/check: any
	echo $@ done

else

wine:
	env -C source ./tools/make_requests
	env -C source autoreconf

	mkdir -p wine64
	env -C wine64 ../source/configure -q -C --enable-win64 --enable-werror --with-mingw
	$(MAKE) $(JFLAGS) $(MFLAGS) $(MAKEOVERRIDES) -C wine64

	mkdir -p wine32
	env -C wine32 ../source/configure -q -C --enable-werror --with-mingw
	$(MAKE) $(JFLAGS) $(MFLAGS) $(MAKEOVERRIDES) -C wine32

	-ln -sf ../source/tools/winewrapper wine32/wine
	-ln -sf ../source/tools/winewrapper wine32/wine64
	-ln -sf ../source/tools/winewrapper wine64/wine
	-ln -sf ../source/tools/winewrapper wine64/wine64
	-ln -sf ../../wine64/loader/wine64 wine32/loader/wine64
	-ln -sf ../../wine64/loader/wine64-preloader wine32/loader/wine64-preloader
	-ln -sf ../../wine32/loader/wine wine64/loader/wine
	-ln -sf ../../wine32/loader/wine-preloader wine64/loader/wine-preloader

define xorg.conf
Section "Device"
	Identifier "dummy"
	Driver "dummy"
	VideoRam 32768
EndSection
endef

tests/init:
	echo '$(subst $(newline),\n,$(xorg.conf))' >$(HOME)/xorg.conf
	echo 'exec /usr/bin/fvwm -f config -c "Style * MwmDecor" 2>/dev/null' >$(HOME)/.xinitrc
	startx -- -config $(HOME)/xorg.conf $(DISPLAY) &
	pulseaudio --start --exit-idle-time=-1

make-test = $(word 1,$(subst /, ,$(1)))$(filter-out :check,$(patsubst %.ok,%,:$(word 3,$(subst /, ,$(1)))))
WINETESTS := $(foreach f,$(filter %/check,$(MAKECMDGOALS)) $(filter %.ok,$(MAKECMDGOALS)),$(call make-test,$(f)))

tests/win32: export WINEARCH=win32
tests/win32: export WINE=$(CURDIR)/wine32/wine
tests/win32: export WINEPREFIX=$(CURDIR)/winetest/win32
tests/win32: export WINESERVER=$(CURDIR)/wine32/server/wineserver
tests/win32: export WINETEST=$(CURDIR)/wine32/programs/winetest/i386-windows/winetest.exe
tests/win32: wine tests/init
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX); $(WINE) wineboot; $(WINESERVER) -kw
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && fail)

tests/wow32: export WINEARCH=win64
tests/wow32: export WINE=$(CURDIR)/wine64/wine
tests/wow32: export WINEPREFIX=$(CURDIR)/winetest/wow32
tests/wow32: export WINESERVER=$(CURDIR)/wine64/server/wineserver
tests/wow32: export WINETEST=$(CURDIR)/wine32/programs/winetest/i386-windows/winetest.exe
tests/wow32: wine tests/init
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX); $(WINE) wineboot; $(WINESERVER) -kw
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && fail)

tests/wow64: export WINEARCH=win64
tests/wow64: export WINE=$(CURDIR)/wine64/wine
tests/wow64: export WINEPREFIX=$(CURDIR)/winetest/wow64
tests/wow64: export WINESERVER=$(CURDIR)/wine64/server/wineserver
tests/wow64: export WINETEST=$(CURDIR)/wine64/programs/winetest/x86_64-windows/winetest.exe
tests/wow64: wine tests/init
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX); $(WINE) wineboot; $(WINESERVER) -kw
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && fail)

%/check: export WINED3D_CONFIG=csmt=0
%/check: export LP_NUM_THREADS=0
%/check: export DISPLAY=:0
%/check: tests/win32 tests/wow32 tests/wow64
	echo $@ done
.PHONY: %/check

%.ok: export WINED3D_CONFIG=csmt=0
%.ok: export LP_NUM_THREADS=0
%.ok: export DISPLAY=:0
%.ok: tests/win32 tests/wow32 tests/wow64
	echo $@ done
.PHONY: %.ok

endif
