OBJ := $(abspath $(CURDIR))
BUILD := $(notdir $(OBJ))

include ../make/silent.mk
include ../make/utility.mk
include ../make/rules-source.mk

all: wine
.PHONY: all

remains = $(filter-out $(cmdtgts),$(MAKECMDGOALS))
cmdtgts :=
targets := $(filter dlls/% programs/% libs/% server/% loader/%,$(remains))
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

DOCKER_SHELL = docker run --rm -e HOME -e USER -e USERID=$(shell id -u) -u $(shell id -u):$(shell id -g) \
                 -v $(HOME)/.ccache:$(HOME)/.ccache -v $(HOME)/.cache:$(HOME)/.cache \
                 -v $(WINE_SRC):$(WINE_SRC) -v $(OBJ):$(OBJ) -w $(OBJ) -e MAKEFLAGS \
								 -v $(HOME)/Code/wine-ext:$(HOME)/Code/wine-ext \
                 -e CCACHE_COMPILERCHECK=none \
                 $(DOCKER_IMAGE_$(1)) $(SHELL)

DOCKER_IMAGE_32 = rbernon/wine-i686:stable
DOCKER_IMAGE_64 = rbernon/wine-x86_64:stable

CONFIGURE_OPTS ?= --with-mingw CROSSDEBUG=split
CONFIGURE_OPTS_64 ?= --enable-win64
CONFIGURE_OPTS_32 ?=
# --with-wine64=$(OBJ)/wine64

CFLAGS ?= -O2 -ggdb -ffunction-sections -fdata-sections -fno-omit-frame-pointer
CFLAGS += -ffile-prefix-map=$(WINE_SRC)=.
# CROSSLDFLAGS += -Wl,--insert-timestamp
LDFLAGS = -Wl,--no-gc-sections

ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine)
ifneq ($(lastword $(subst /, ,$(OBJ))),build-wine-remote)
CONFIGURE_OPTS += --disable-tests
endif
endif

ifeq ($(lastword $(subst /, ,$(OBJ))),build-wine-llvm)
DOCKER_IMAGE_32 = rbernon/wine-llvm-i686:experimental
DOCKER_IMAGE_64 = rbernon/wine-llvm-x86_64:experimental
# CONFIGURE_OPTS += DELAYLOADFLAG=-Wl,-delayload, CROSSDEBUG=pdb
# CROSSCFLAGS += -Wno-pragma-pack -gcodeview
else
CFLAGS += -Wno-misleading-indentation -Wno-array-bounds -Wno-sizeof-array-div -Wno-maybe-uninitialized
endif

ARCH_32 = i386-linux-gnu
ARCH_64 = x86_64-linux-gnu

WINE_SOURCE_ARGS = \
  --exclude configure \
  --exclude autom4te.cache \
  --exclude include/config.h.in \

WINE_SRC := $(abspath source)
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
	cd $(WINE_SRC) && dlls/winevulkan/make_vulkan
	touch $@

$(OBJ)/.wine-post-source: $(WINE_SRC)/dlls/winevulkan/vulkan_thunks.c
$(OBJ)/.wine-post-source: $(WINE_SRC)/configure $(WINE_SRC)/server/trace.c $(WINE_SRC)/dlls/winevulkan/vulkan_thunks.c
	touch $@

J := $(shell nproc)
JFLAGS = -j$(J) $(filter -j%,$(MAKEFLAGS))

define create-build-rules
wine$(1)/Makefile: private SHELL := $(DOCKER_SHELL)
wine$(1)/Makefile: $$(shell mkdir -p wine$(1)) | $$(WINE_SRC)/configure
	env -C wine$(1) CCACHE_BASEDIR=$$(abspath $$(WINE_SRC)) PATH=/usr/lib/ccache:/usr/bin:/bin \
	$$(WINE_SRC)/configure $(--quiet?) -C \
	                CFLAGS="$(strip $(CFLAGS))" CROSSCFLAGS="$(strip $(CFLAGS) $(CROSSCFLAGS))" \
	                LDFLAGS="$(strip $(LDFLAGS))" CROSSLDFLAGS="$(strip $(LDFLAGS) $(CROSSLDFLAGS) $(CROSSLDFLAGS_$(1)))" \
	                $(CONFIGURE_OPTS) $(CONFIGURE_OPTS_$(1)) && \
	(touch $$@ 2>/dev/null||:)

.wine-config$(1): wine$(1)/Makefile
	(touch $$@ 2>/dev/null||:)

.wine-build$(1): private SHELL := $(DOCKER_SHELL)
.wine-build$(1): .wine-config$(1) wine-source
	+env -C wine$(1) CCACHE_BASEDIR=$$(abspath $$(WINE_SRC)) PATH=/usr/lib/ccache:/usr/bin:/bin \
	$$(MAKE) $$(JFLAGS) $$(MFLAGS) $$(MAKEOVERRIDES) $(targets) && \
	(touch $$@ 2>/dev/null||:)

wine$(1): .wine-build$(1)
.PHONY: wine$(1)

install$(1): private SHELL := $(DOCKER_SHELL)
install$(1): wine$(1)
	+env -C wine$(1) CCACHE_BASEDIR=$$(abspath $$(WINE_SRC)) PATH=/usr/lib/ccache:/usr/bin:/bin \
	$$(MAKE) $$(JFLAGS) $$(MFLAGS) $$(MAKEOVERRIDES) install

clean::
	rm -rf wine$(1) "$(HOME)/.cache/autoconf/$(BUILD)$(1)"
endef

$(eval $(call create-build-rules,32))
$(eval $(call create-build-rules,64))

.wine-config32: .wine-config64
.wine-build32: .wine-build64

wine32: wine64
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
	cd .. && python3 compile_commands.py

install64: install32
install: install32 install64

ifeq ($(MAKELEVEL),0)

ifneq ($(DISPLAY),)
test-init: wine
	Xephyr -sw-cursor -br -ac -glamor -screen 1280x720 $(D) & sleep 1
	env DISPLAY=$(D) fvwm 2>/dev/null &
#	env DISPLAY=$(D) metacity --no-composite --sm-disable 2>/dev/null &
#	env DISPLAY=$(D) setxkbmap us
# 	env DISPLAY=$(D) openbox --sm-disable 2>/dev/null &
else
test-init: wine
endif

test-exec: test-init
	+$(MAKE) -f $(firstword $(MAKEFILE_LIST)) $(MAKECMDGOALS) DISPLAY=$(D) || (killall Xephyr; exit 1)

ifneq ($(DISPLAY),)
test-fini: test-exec
	killall Xephyr
else
test-fini: test-exec
endif

%.ok %/tests/check: D=$(patsubst :%,:9,$(DISPLAY))
%.ok %/tests/check: test-init test-exec test-fini
	echo $@ done

else

ifeq ($(NOWINETEST),)

make-test = $(word 1,$(subst /, ,$(1)))$(filter-out :check,$(patsubst %.ok,%,:$(word 3,$(subst /, ,$(1)))))
WINETESTS := $(foreach f,$(filter %/check,$(MAKECMDGOALS)) $(filter %.ok,$(MAKECMDGOALS)),$(call make-test,$(f)))

tests/win32: export WINE=$(CURDIR)/wine32/wine
tests/win32: export WINEARCH=win32
tests/win32: export WINEPREFIX=$(CURDIR)/winetest/win32
tests/win32: export WINESERVER=$(CURDIR)/wine32/server/wineserver
tests/win32: export WINETEST=$(CURDIR)/wine32/programs/winetest/winetest.exe
tests/win32: 
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit $(WINETESTS)
	-grep "Test failed" $(WINEPREFIX).report

tests/wow32: export WINE=$(CURDIR)/wine32/wine
tests/wow32: export WINEARCH=win64
tests/wow32: export WINEPREFIX=$(CURDIR)/winetest/wow32
tests/wow32: export WINESERVER=$(CURDIR)/wine64/server/wineserver
tests/wow32: export WINETEST=$(CURDIR)/wine32/programs/winetest/winetest.exe
tests/wow32: 
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit $(WINETESTS)
	-grep "Test failed" $(WINEPREFIX).report

tests/wow64: export WINE=$(CURDIR)/wine64/wine
tests/wow64: export WINEARCH=win64
tests/wow64: export WINEPREFIX=$(CURDIR)/winetest/wow64
tests/wow64: export WINESERVER=$(CURDIR)/wine64/server/wineserver
tests/wow64: export WINETEST=$(CURDIR)/wine64/programs/winetest/winetest.exe
tests/wow64: 
	-$(WINESERVER) -kw; rm -rf $(WINEPREFIX); mkdir -p $(WINEPREFIX)
	$(WINE) $(WINETEST) -c -o $(WINEPREFIX).report -t do.not.submit $(WINETESTS)
	-grep "Test failed" $(WINEPREFIX).report

%/check: tests/win32 tests/wow32 tests/wow64
	echo $@ done
.PHONY: %/check

%.ok: tests/win32 tests/wow32 tests/wow64
	echo $@ done
.PHONY: %.ok

else

%/tests/check: export WINEPREFIX=$(HOME)/.wine-test
%/tests/check:
	-wine64/wine wineboot -u
	$(MAKE) -C wine32 dlls/$@ $(TESTFLAGS)
	$(MAKE) -C wine64 dlls/$@ $(TESTFLAGS)
.PHONY: %/tests/check

%.ok: export WINEPREFIX=$(HOME)/.wine-test
%.ok:
	rm -rf $(WINEPREFIX) && mkdir -p $(WINEPREFIX)
	-wine64/server/wineserver
	$(MAKE) -C wine32 dlls/$@ $(TESTFLAGS)
	$(MAKE) -C wine64 dlls/$@ $(TESTFLAGS)
	-wine64/server/wineserver -kw
.PHONY: %.ok

endif
endif

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
