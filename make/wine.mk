OBJ := $(abspath $(CURDIR))
BUILD := $(notdir $(OBJ))
WINE_SRC := $(abspath source)

J := $(shell nproc)
JFLAGS = -j$(J) $(filter -j%,$(MAKEFLAGS))

include ../make/silent.mk
include ../make/utility.mk
include ../make/rules-source.mk

all: wine
.PHONY: all


remains = $(filter-out $(cmdtgts),$(MAKECMDGOALS))
cmdtgts :=
targets := $(filter dlls/% programs/% tools/% libs/% server/% loader/%,$(remains))
cmdtgts += $(filter $(targets),$(remains))
targets += $(foreach d,$(patsubst %.dll.so,%,$(filter %.dll.so,$(remains))),dlls/$(d)/$(d).dll.so)
cmdtgts += $(filter %.dll.so,$(remains))
targets += $(foreach d,$(patsubst %.exe.so,%,$(filter %.exe.so,$(remains))),programs/$(d)/$(d).exe.so)
cmdtgts += $(filter %.exe.so,$(remains))
targets += $(foreach d,$(patsubst %.so,%,$(filter %.so,$(remains))),dlls/$(d)/$(d).so)
cmdtgts += $(filter %.so,$(remains))
targets += $(foreach d,$(patsubst %.dll,%,$(filter %.dll,$(remains))),dlls/$(d)/$(d).dll)
cmdtgts += $(filter %.dll,$(remains))
targets += $(foreach d,$(patsubst %.exe,%,$(filter %.exe,$(remains))),programs/$(d)/$(d).exe)
cmdtgts += $(filter %.exe,$(remains))

ifneq ($(cmdtgts),)
$(cmdtgts): wine
.PHONY: $(cmdtgts)
endif


ifeq ($(MAKELEVEL),0)

DOCKER_SHELL = docker run --rm -e HOME -e USER -e USERID=$(shell id -u) -u $(shell id -u):$(shell id -g) \
                 -v $(CURDIR)/.home:$(HOME) -v $(HOME)/.ccache:$(HOME)/.ccache -v $(HOME)/.cache:$(HOME)/.cache \
                 -v $(WINE_SRC):$(WINE_SRC) -v $(OBJ):$(OBJ) -v $(OBJ)/../make:$(OBJ)/../make -w $(OBJ) -e MAKEFLAGS \
                 -e WINE -e WINEDLLOVERRIDES -e WINEARCH -e WINEPREFIX -e WINESERVER -e WINETEST -e WINEDEBUG \
                 -e GST_DEBUG -e GST_DEBUG_NO_COLOR -e CCACHE_COMPILERCHECK=none \
                 $(DOCKER_IMAGE) $(SHELL)
ifeq ($(lastword $(subst /, ,$(OBJ))),build-wine-llvm)
DOCKER_IMAGE = rbernon/wine-llvm:experimental
else
DOCKER_IMAGE = rbernon/wine:experimental
endif

WINE_SOURCE_ARGS = \
  --exclude configure \
  --exclude autom4te.cache \
  --exclude include/config.h.in \

$(eval $(call rules-source,wine,$(abspath $(WINE))))

# $(WINE_SRC)/configure.ac: | wine-source
# $(WINE_SRC)/server/protocol.def: | wine-source
# $(WINE_SRC)/configure: $(WINE_SRC)/configure.ac
# 	cd $(WINE_SRC) && autoreconf -i && rm autom4te.cache -rf
# 	touch $@ -f $(abspath $(WINE))/configure
# $(WINE_SRC)/server/trace.c: $(WINE_SRC)/server/protocol.def
# $(WINE_SRC)/server/request.h: $(WINE_SRC)/server/protocol.def
# $(WINE_SRC)/include/wine/server_protocol.h: $(WINE_SRC)/server/protocol.def
# 	-cd $(WINE_SRC) && tools/make_requests && git diff | grep 'define SERVER_PROTOCOL' -C6 | tee requests.patch | patch -p1 -R
# 	-cd $(WINE_SRC) && [ -n "$(git diff)" ] && git apply requests.patch

$(WINE_SRC)/configure: $(WINE)/configure.ac | $(OBJ)/.wine-source
	cd $(WINE_SRC) && autoreconf -fi
	touch $@

$(WINE_SRC)/server/trace.c: $(WINE)/server/protocol.def | $(OBJ)/.wine-source
	cd $(WINE_SRC) && tools/make_requests
	touch $@

$(WINE_SRC)/dlls/winevulkan/vulkan_thunks.c: $(WINE)/dlls/winevulkan/make_vulkan | $(OBJ)/.wine-source
	# cd $(WINE_SRC) && dlls/winevulkan/make_vulkan 2>/dev/null
	touch $@

$(OBJ)/.wine-post-source: $(WINE_SRC)/dlls/winevulkan/vulkan_thunks.c
$(OBJ)/.wine-post-source: $(WINE_SRC)/configure $(WINE_SRC)/server/trace.c $(WINE_SRC)/dlls/winevulkan/vulkan_thunks.c
	touch $@

any: $(shell mkdir -p .home/.cache .home/.ccache .home/Code/build-wine)
any: private SHELL := $(DOCKER_SHELL)
any: wine-source
	+$(MAKE) $(JFLAGS) -f $(firstword $(MAKEFILE_LIST)) $(MAKECMDGOALS) MAKELEVEL=1
.PHONY: any

tests: $(shell mkdir -p .home/.cache .home/.ccache .home/Code/build-wine)
tests: private SHELL := $(call DOCKER_SHELL,tests)
tests: wine
	+$(MAKE) -f $(firstword $(MAKEFILE_LIST)) $(MAKECMDGOALS) MAKELEVEL=1

wine tests: any
%.ok %/tests/check: any
	-env -C .. python3 compile_commands.py proton
	-env -C .. python3 compile_commands.py $(subst build-,,$(lastword $(subst /, ,$(OBJ))))
	echo $@ done

else # MAKELEVEL

CONFIGURE_OPTS_64 ?= --host x86_64-linux-gnu PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig --enable-win64 --enable-archs=i386,x86_64
CONFIGURE_OPTS_32 ?= --host i686-linux-gnu PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig

ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-default)
CONFIGURE_OPTS ?= --with-mingw # CROSSDEBUG=split
CFLAGS ?= -O2 -ggdb -ffunction-sections -fdata-sections -fno-omit-frame-pointer
CFLAGS += -ffile-prefix-map=$(WINE_SRC)=.
# CROSSLDFLAGS += -Wl,--insert-timestamp
LDFLAGS = -Wl,--no-gc-sections
endif

ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine)
ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-remote)
ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-default)
CONFIGURE_OPTS += --disable-tests
endif
endif
endif

ifeq ($(lastword $(subst /, ,$(OBJ))),build-wine-llvm)
CFLAGS += -Wno-ignored-attributes -Wno-format -Wno-error
# CONFIGURE_OPTS += DELAYLOADFLAG=-Wl,-delayload, CROSSDEBUG=pdb
# CROSSCFLAGS += -Wno-pragma-pack -gcodeview
endif

ARCH_32 = i386-linux-gnu
ARCH_64 = x86_64-linux-gnu

arch-32 = $(subst x86_64-windows,i386-windows,$(1))
arch-64 = $(subst i386-windows,x86_64-windows,$(1))

define create-build-rules
wine$(1)/Makefile: $$(shell mkdir -p wine$(1)) | $$(WINE_SRC)/configure
	env -C wine$(1) CCACHE_BASEDIR=$$(abspath $$(WINE_SRC)) PATH=/usr/lib/ccache:/usr/bin:/bin \
	$$(WINE_SRC)/configure $(--quiet?) -C \
	                CFLAGS="$(strip $(CFLAGS) $(CFLAGS$(1)))" CROSSCFLAGS="$(strip $(CFLAGS) $(CFLAGS$(1)) $(CROSSCFLAGS))" \
	                LDFLAGS="$(strip $(LDFLAGS))" CROSSLDFLAGS="$(strip $(LDFLAGS) $(CROSSLDFLAGS) $(CROSSLDFLAGS_$(1)))" \
	                $(CONFIGURE_OPTS) $(CONFIGURE_OPTS_$(1))
	touch $$@

wine$(1): wine$(1)/Makefile
	+env -C wine$(1) CCACHE_BASEDIR=$$(abspath $$(WINE_SRC)) PATH=/usr/lib/ccache:/usr/bin:/bin \
	$$(MAKE) $$(MAKEOVERRIDES) $$(call arch-$(1),$$(targets))
.PHONY: wine$(1)
endef

$(eval $(call create-build-rules,32))
$(eval $(call create-build-rules,64))

wine: wine32 wine64
	-rm -f {wine32,wine64}/{wine,wine64}
	-rm -f {wine32,wine64}/{fonts,nls}/*
	-rm -f {wine32,wine64}/loader/{wine,wine64}{,-preloader}
	-ln -sf ../source/tools/winewrapper wine32/wine
	-ln -sf ../source/tools/winewrapper wine32/wine64
	-ln -sf ../source/tools/winewrapper wine64/wine
	-ln -sf ../source/tools/winewrapper wine64/wine64
	-cp 2>/dev/null -af $(abspath source/fonts)/* wine32/fonts/
	-cp 2>/dev/null -af $(abspath source/nls)/* wine32/nls/
	-cp 2>/dev/null -af $(abspath source/fonts)/* wine64/fonts/
	-cp 2>/dev/null -af $(abspath source/nls)/* wine64/nls/
	-ln -sf ../../wine64/loader/wine64 wine32/loader/wine64
	-ln -sf ../../wine64/loader/wine64-preloader wine32/loader/wine64-preloader
	-ln -sf ../../wine32/loader/wine wine64/loader/wine
	-ln -sf ../../wine32/loader/wine-preloader wine64/loader/wine-preloader
	touch $@
.PHONY: wine

define xorg.conf
Section "Device"
	Identifier "dummy"
	Driver "dummy"
	VideoRam 32768
EndSection
endef

MONITORS := 2

tests/init: wine
	echo '$(subst $(newline),\n,$(xorg.conf))' >$(HOME)/xorg.conf
	echo 'exec /usr/bin/fvwm -f config -c "Style * MwmDecor" 2>/dev/null' >$(HOME)/.xinitrc
	# echo 'exec /usr/bin/kwin_x11' >$(HOME)/.xinitrc
	env -C $(HOME) startx -- -config xorg.conf $(DISPLAY) 2>/dev/null & sleep 1
ifeq ($(MONITORS),2)
	xrandr --addmode DUMMY1 1024x768
	xrandr --output DUMMY0 --auto \
	       --output DUMMY1 --right-of DUMMY0 --mode 1024x768
endif
ifeq ($(MONITORS),3)
	xrandr --addmode DUMMY1 1024x768 \
	       --addmode DUMMY2 1024x768
	xrandr --output DUMMY0 --auto \
	       --output DUMMY1 --right-of DUMMY0 --mode 1024x768 \
	       --output DUMMY2 --right-of DUMMY1 --mode 1024x768
endif
	xrandr 1>/dev/null
	# ibus-daemon --verbose &
	pulseaudio --start --exit-idle-time=-1
	# setxkbmap -layout us,fr,de,us -variant ,,,dvorak

make-test = $(word 1,$(subst /, ,$(1)))$(filter-out :check,$(patsubst %.ok,%,:$(word 3,$(subst /, ,$(1)))))
WINETESTS := $(foreach f,$(filter %/check,$(MAKECMDGOALS)) $(filter %.ok,$(MAKECMDGOALS)),$(call make-test,$(f)))

tests/win32: export WINEARCH=win32
tests/win32: export WINE=$(CURDIR)/wine32/wine
tests/win32: export WINEPREFIX=$(CURDIR)/winetest/win32
tests/win32: export WINESERVER=$(CURDIR)/wine32/server/wineserver
tests/win32: export WINETEST=$(CURDIR)/wine32/programs/winetest/i386-windows/winetest.exe
tests/win32: tests/init
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX); WINEDEBUG=-all $(WINE) wineboot; $(WINESERVER) -kw
ifeq ($(NOWINETEST),)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit -u localhost $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && false)
else
	$(MAKE) -C wine32 $(foreach f,$(subst tests,.*,$(MAKECMDGOALS)),$(subst :, ,$(firstword $(shell grep $(f) wine32/Makefile))))
endif

tests/wow32: export WINEARCH=win64
tests/wow32: export WINE=$(CURDIR)/wine64/wine
tests/wow32: export WINEPREFIX=$(CURDIR)/winetest/wow32
tests/wow32: export WINESERVER=$(CURDIR)/wine64/server/wineserver
tests/wow32: export WINETEST=$(CURDIR)/wine32/programs/winetest/i386-windows/winetest.exe
tests/wow32: tests/init tests/win32
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX); WINEDEBUG=-all $(WINE) wineboot; $(WINESERVER) -kw
ifeq ($(NOWINETEST),)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit -u localhost $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && false)
else
	$(MAKE) -C wine32 $(foreach f,$(subst tests,.*,$(MAKECMDGOALS)),$(subst :, ,$(firstword $(shell grep $(f) wine32/Makefile))))
endif

tests/wow64: export WINEARCH=win64
tests/wow64: export WINE=$(CURDIR)/wine64/wine
tests/wow64: export WINEPREFIX=$(CURDIR)/winetest/wow64
tests/wow64: export WINESERVER=$(CURDIR)/wine64/server/wineserver
tests/wow64: export WINETEST=$(CURDIR)/wine64/programs/winetest/x86_64-windows/winetest.exe
tests/wow64: tests/init tests/wow32
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX); WINEDEBUG=-all $(WINE) wineboot; $(WINESERVER) -kw
ifeq ($(NOWINETEST),)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit -u localhost $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && false)
else
	$(MAKE) -C wine64 $(foreach f,$(subst tests,.*,$(MAKECMDGOALS)),$(subst :, ,$(firstword $(shell grep $(f) wine64/Makefile))))
endif

tests: export WINED3D_CONFIG=csmt=0
tests: export LP_NUM_THREADS=0
tests: export DISPLAY=:0
ifeq ($(TESTEXE),)
tests: tests/win32 tests/wow32 tests/wow64
else
tests: export WINE=$(CURDIR)/wine64/wine
tests: export WINEPREFIX=$(CURDIR)/pfx
tests: export WINESERVER=$(CURDIR)/wine64/server/wineserver
tests: tests/init
	$(WINE) $(TESTEXE)
endif

%.ok %/tests/check: tests
	echo $@ done

endif # MAKELEVEL


# .NOTPARALLEL:
.SUFFIXES:


flamegraph: export DISPLAY :=
flamegraph: export FONTCONFIG_FILE := $(OBJ)/fontconfig
flamegraph: export WINEPREFIX := $(OBJ)/pfx
# flamegraph: export WINEDLLOVERRIDES := winemenubuilder.exe=d
flamegraph: export PATH := $(HOME)/Code/debug:$(HOME)/Code/debug/FlameGraph:$(PATH)
flamegraph:
	-wine64/server/wineserver -kw
#	-wine64/wine winecfg & sleep 5
# 	-for i in $(shell seq 0 30); do wine64/wine cmd /c exit; wine64/server/wineserver -kw; done
# 	-wine64/wine cmd /c exit
	-rm $$WINEPREFIX -rf
# 	-perf record --call-graph=dwarf -Fmax wine64/wine wineboot -u
# 	-perf record --all-user --call-graph=dwarf -Fmax wine64/wine winemenubuilder -a -r
# 	-perf record --call-graph=dwarf wine64/wine cmd /c exit

# 	-wine64/wine uninstaller --remove '{BEF75720-E23F-5A02-B01F-CE9B220A1B92}'
# 	-perf record --call-graph=dwarf wine64/wine msiexec /i ~/.cache/wine/wine-mono-7.0.0-x86.msi

	-perf record --call-graph=dwarf -Fmax wine64/wine cmd /c exit
	perf script | stackcollapse-perf.pl | flamegraph.pl --width 1920 --bgcolors grey --hash --colors yellow --fonttype "mono" --fontsize 11 - > perf.svg
	# firefox perf.svg
