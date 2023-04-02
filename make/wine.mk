OBJ := $(abspath $(CURDIR))
BUILD := $(notdir $(OBJ))
WINE_SRC := $(abspath wine)

J := $(shell nproc)
JFLAGS = -j$(J) $(filter -j%,$(MAKEFLAGS))

include ../make/silent.mk
include ../make/utility.mk
include ../make/rules-source.mk


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

all: wine
	-env -C .. python3 compile_commands.py proton
	-env -C .. python3 compile_commands.py $(subst build-,,$(lastword $(subst /, ,$(OBJ))))
.PHONY: all

DOCKER_SHELL = docker run --rm -e HOME -e USER -e USERID=$(shell id -u) -u $(shell id -u):$(shell id -g) \
                 -v $(CURDIR)/.home:$(HOME) -v $(HOME)/.ccache:$(HOME)/.ccache -v $(HOME)/.cache:$(HOME)/.cache \
                 -v $(WINE_SRC):$(WINE_SRC) -v $(OBJ):$(OBJ) -v $(OBJ)/../make:$(OBJ)/../make -w $(OBJ) -e MAKEFLAGS \
                 -e WINE -e WINEDLLOVERRIDES -e WINEARCH -e WINEPREFIX -e WINESERVER -e WINETEST -e WINEDEBUG \
                 -e GST_DEBUG -e GST_DEBUG_NO_COLOR -e CCACHE_COMPILERCHECK=none -e LC_ALL=C.UTF-8 -e XDG_RUNTIME_DIR=$(HOME)/.local/run \
                 $(DOCKER_IMAGE) $(SHELL)
ifeq ($(lastword $(subst /, ,$(OBJ))),build-wine-llvm)
DOCKER_IMAGE = rbernon/wine-llvm:experimental
else
ifeq ($(lastword $(subst /, ,$(OBJ))),build-wine-gitlab)
DOCKER_IMAGE = rbernon/winehq:latest
else
DOCKER_IMAGE = rbernon/wine:experimental
endif
endif

WINE_SOURCE_ARGS = \
  --exclude configure \
  --exclude autom4te.cache \
  --exclude include/config.h.in \

$(eval $(call rules-source,wine,$(abspath $(WINE))))

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

any: $(shell mkdir -p .home/.cache .home/.ccache .home/.local/run .home/Code/build-wine && chmod 700 .home/.local/run)
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
	echo $@ done

else # MAKELEVEL

all: wine
.PHONY: all

ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-gitlab)
CONFIGURE_OPTS_64 ?= --host x86_64-linux-gnu PKG_CONFIG_PATH=/usr/lib/x86_64-linux-gnu/pkgconfig --enable-win64 --enable-archs=i386,x86_64
CONFIGURE_OPTS_32 ?= --host i686-linux-gnu PKG_CONFIG_PATH=/usr/lib/i386-linux-gnu/pkgconfig
else
CONFIGURE_OPTS_64 ?= --enable-win64
CONFIGURE_OPTS_32 ?=
endif

ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-default)
CONFIGURE_OPTS ?= --with-mingw # CROSSDEBUG=split
CFLAGS ?= -O2 -ggdb -ffunction-sections -fdata-sections -fno-omit-frame-pointer
CFLAGS += -ffile-prefix-map=$(WINE_SRC)=. -ffile-prefix-map=../wine=.
# CROSSLDFLAGS += -Wl,--insert-timestamp
LDFLAGS = -Wl,--no-gc-sections
endif

ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine)
ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-remote)
ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-default)
ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-gitlab)
CONFIGURE_OPTS += --disable-tests
endif
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
build$(1)/Makefile: $$(shell mkdir -p build$(1)) | $$(WINE_SRC)/configure
	env -C build$(1) CCACHE_BASEDIR=$$(abspath $$(WINE_SRC)) PATH=/usr/lib/ccache:/usr/bin:/bin \
	$$(WINE_SRC)/configure $(--quiet?) -C \
	                CFLAGS="$(strip $(CFLAGS) $(CFLAGS$(1)))" CROSSCFLAGS="$(strip $(CFLAGS) $(CFLAGS$(1)) $(CROSSCFLAGS))" \
	                LDFLAGS="$(strip $(LDFLAGS))" CROSSLDFLAGS="$(strip $(LDFLAGS) $(CROSSLDFLAGS) $(CROSSLDFLAGS_$(1)))" \
	                $(CONFIGURE_OPTS) $(CONFIGURE_OPTS_$(1))
	touch $$@

build$(1): build$(1)/Makefile
	+env -C build$(1) CCACHE_BASEDIR=$$(abspath $$(WINE_SRC)) PATH=/usr/lib/ccache:/usr/bin:/bin \
	$$(MAKE) $$(MAKEOVERRIDES) $$(call arch-$(1),$$(targets))
.PHONY: build$(1)
endef

$(eval $(call create-build-rules,32))
$(eval $(call create-build-rules,64))

wine: build32 build64
	# -rm -f {build32,build64}/{wine,build64}
	# -rm -f {build32,build64}/{fonts,nls}/*
	# -rm -f {build32,build64}/loader/{wine,build64}{,-preloader}
	# -ln -sf ../source/tools/winewrapper build32/wine
	# -ln -sf ../source/tools/winewrapper build32/build64
	# -ln -sf ../source/tools/winewrapper build64/wine
	# -ln -sf ../source/tools/winewrapper build64/build64
	# -cp 2>/dev/null -af $(abspath source/fonts)/* build32/fonts/
	# -cp 2>/dev/null -af $(abspath source/nls)/* build32/nls/
	# -cp 2>/dev/null -af $(abspath source/fonts)/* build64/fonts/
	# -cp 2>/dev/null -af $(abspath source/nls)/* build64/nls/
	# -ln -sf ../../build64/loader/build64 build32/loader/build64
	# -ln -sf ../../build64/loader/build64-preloader build32/loader/build64-preloader
	# -ln -sf ../../build32/loader/wine build64/loader/wine
	# -ln -sf ../../build32/loader/wine-preloader build64/loader/wine-preloader
	ln -sf build32 wine32
	ln -sf build64 wine64
.PHONY: wine

define xorg.conf
Section "Device"
	Identifier "dummy"
	Driver "dummy"
	VideoRam 32768
EndSection
endef

DRIVER := x11
MONITORS := 1
WM := fvwm

WM_EXEC_fvwm := /usr/bin/fvwm -f config -c "Style * MwmDecor" -c "Style * UsePPosition"
WM_EXEC_kwin := /usr/bin/kwin_x11
WM_EXEC_mutter := /usr/bin/mutter --x11
WM_EXEC_openbox := /usr/bin/openbox

tests/init: wine
ifeq ($(DRIVER),wayland)
	weston --backend=headless-backend.so &
endif
ifeq ($(DRIVER),x11)
	echo '$(subst $(newline),\n,$(xorg.conf))' >$(HOME)/xorg.conf
	echo 'exec $(WM_EXEC_$(WM)) 2>/dev/null' >$(HOME)/.xinitrc
	env -C $(HOME) startx -- -config xorg.conf $(DISPLAY) & sleep 1
ifeq ($(MONITORS),2)
	xrandr --addmode DUMMY1 1024x768
	xrandr --output DUMMY0 --auto \
	       --output DUMMY1 --right-of DUMMY0 --mode 1024x768
	xrandr 1>/dev/null
endif
ifeq ($(MONITORS),3)
	xrandr --addmode DUMMY1 1024x768 \
	       --addmode DUMMY2 1024x768
	xrandr --output DUMMY0 --auto \
	       --output DUMMY1 --right-of DUMMY0 --mode 1024x768 \
	       --output DUMMY2 --right-of DUMMY1 --mode 1024x768
	xrandr 1>/dev/null
endif
endif
	# ibus-daemon --verbose &
	pulseaudio --start --exit-idle-time=-1
	# setxkbmap -layout us,fr,de,us -variant ,,,dvorak

make-test = $(word 1,$(subst /, ,$(1)))$(filter-out :check,$(patsubst %.ok,%,:$(word 3,$(subst /, ,$(1)))))
WINETESTS := $(foreach f,$(filter %/check,$(MAKECMDGOALS)) $(filter %.ok,$(MAKECMDGOALS)),$(call make-test,$(f)))
ifeq ($(strip $(WINETESTS)),)
WINETESTS := -n d3d10core:d3d10core d3d11:d3d11 d3d8:device d3d8:visual d3d9:d3d9ex d3d9:device d3d9:visual
endif

tests/win32: export WINEARCH=win32
tests/win32: export WINE=$(CURDIR)/build32/wine
tests/win32: export WINEPREFIX=$(CURDIR)/winetest/win32
tests/win32: export WINESERVER=$(CURDIR)/build32/server/wineserver
tests/win32: export WINETEST=$(CURDIR)/build32/programs/winetest/i386-windows/winetest.exe
tests/win32: tests/init
	-rm -rf $(WINEPREFIX) && mkdir -p $(WINEPREFIX);
	-WINEDEBUG=-all $(WINE) reg add HKCU\\Software\\Wine\\Drivers /v Graphics /d $(DRIVER) /f
	-$(WINESERVER) -kw
ifeq ($(NOWINETEST),)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t none -u localhost $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && false)
else
	$(MAKE) -C build32 $(foreach f,$(subst tests,.*,$(MAKECMDGOALS)),$(subst :, ,$(firstword $(shell grep $(f) build32/Makefile))))
endif

tests/win64: export WINEARCH=win64
tests/win64: export WINE=$(CURDIR)/build64/wine
tests/win64: export WINEPREFIX=$(CURDIR)/winetest/win64
tests/win64: export WINESERVER=$(CURDIR)/build64/server/wineserver
tests/win64: export WINETEST=$(CURDIR)/build64/programs/winetest/x86_64-windows/winetest.exe
tests/win64: tests/init tests/win32
	-rm -rf $(WINEPREFIX) && mkdir -p $(WINEPREFIX);
	-WINEDEBUG=-all $(WINE) reg add HKCU\\Software\\Wine\\Drivers /v Graphics /d $(DRIVER) /f
	-$(WINESERVER) -kw
ifeq ($(NOWINETEST),)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t none -u localhost $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && false)
else
	$(MAKE) -C build64 $(foreach f,$(subst tests,.*,$(MAKECMDGOALS)),$(subst :, ,$(firstword $(shell grep $(f) build64/Makefile))))
endif

tests/wow64: export WINEARCH=win64
tests/wow64: export WINE=$(CURDIR)/build64/wine
tests/wow64: export WINEPREFIX=$(CURDIR)/winetest/wow64
tests/wow64: export WINESERVER=$(CURDIR)/build64/server/wineserver
tests/wow64: export WINETEST=$(CURDIR)/build32/programs/winetest/i386-windows/winetest.exe
tests/wow64: tests/init tests/win64
	-rm -rf $(WINEPREFIX) && mkdir -p $(WINEPREFIX);
	-WINEDEBUG=-all $(WINE) reg add HKCU\\Software\\Wine\\Drivers /v Graphics /d $(DRIVER) /f
	-$(WINESERVER) -kw
ifeq ($(NOWINETEST),)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t none -u localhost $(WINETESTS) || \
	(grep -e "Test failed" -e "Test succeeded" $(WINEPREFIX).report && false)
else
	$(MAKE) -C build32 $(foreach f,$(subst tests,.*,$(MAKECMDGOALS)),$(subst :, ,$(firstword $(shell grep $(f) build32/Makefile))))
endif

tests: export WINED3D_CONFIG=csmt=0
tests: export LP_NUM_THREADS=0
tests: export DISPLAY=:0
ifeq ($(TESTEXE),)
tests: tests/win32 tests/win64 # tests/wow64
else
tests: export WINE=$(CURDIR)/build64/wine
tests: export WINEPREFIX=$(CURDIR)/pfx
tests: export WINESERVER=$(CURDIR)/build64/server/wineserver
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
	-build64/server/wineserver -kw
#	-build64/wine winecfg & sleep 5
# 	-for i in $(shell seq 0 30); do build64/wine cmd /c exit; build64/server/wineserver -kw; done
# 	-build64/wine cmd /c exit
	-rm $$WINEPREFIX -rf
# 	-perf record --call-graph=dwarf -Fmax build64/wine wineboot -u
# 	-perf record --all-user --call-graph=dwarf -Fmax build64/wine winemenubuilder -a -r
# 	-perf record --call-graph=dwarf build64/wine cmd /c exit

# 	-build64/wine uninstaller --remove '{BEF75720-E23F-5A02-B01F-CE9B220A1B92}'
# 	-perf record --call-graph=dwarf build64/wine msiexec /i ~/.cache/wine/wine-mono-7.0.0-x86.msi

	-perf record --call-graph=dwarf -Fmax build64/wine cmd /c exit
	perf script | stackcollapse-perf.pl | flamegraph.pl --width 1920 --bgcolors grey --hash --colors yellow --fonttype "mono" --fontsize 11 - > perf.svg
	# firefox perf.svg
