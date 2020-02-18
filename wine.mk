TOP := $(abspath $(CURDIR))
BUILD := $(notdir $(CURDIR))

CC := gcc
CXX := g++

CC64 ?= x86_64-linux-gnu-$(CC)
CC32 ?= i686-linux-gnu-$(CC)
CXX32 := $(CC32:$(CC)=$(CXX))
CXX64 := $(CC64:$(CC)=$(CXX))
CROSSCC64 := $(CC64:%-linux-gnu-$(CC)=%-w64-mingw32-$(CC))
CROSSCC32 := $(CC32:%-linux-gnu-$(CC)=%-w64-mingw32-$(CC))

# export CCACHE_DEBUG := 1
export LC_ALL=C

include ../make/silent.mk
include ../make/rules-source.mk

CFLAGS ?= -O2 -g -ffile-prefix-map=$(abspath source)=.

all: wine
.PHONY: all

clean:
.PHONY: clean

distclean: clean
.PHONY: distclean

wine-goals := $(filter dlls/% programs/% libs/% server/% loader/%,$(MAKECMDGOALS))
ifneq ($(wine-goals),)
$(wine-goals): wine
endif

DOCKER_SHELL = docker run --rm --init -u $(shell id -u):$(shell id -g) \
                                      -v $(HOME):$(HOME) \
                                      -w $(CURDIR) \
                                      -e HOME=$(HOME) \
                                      -e PATH=$(PATH) \
                                      -e LC_ALL=$(LC_ALL) \
                                      -e CCACHE_BASEDIR=$(CCACHE_BASEDIR) \
                                      -e CCACHE_DEBUG=$(CCACHE_DEBUG) \
                                      $(DOCKER_IMAGE_$(1)) \
                                      /sbin/docker-init -sg -- $(SHELL)
DOCKER_IMAGE_32 = rbernon/wine-i386:latest
DOCKER_IMAGE_64 = rbernon/wine-amd64:latest

CONFIGURE_OPTS ?= --with-mingw
CONFIGURE_OPTS_32 = --with-wine64=$(CURDIR)/wine64
CONFIGURE_OPTS_64 = --enable-win64

ifneq ($(WINE),../wine)
CONFIGURE_OPTS += --disable-tests
endif

ARCH_32 = i386-linux-gnu
ARCH_64 = x86_64-linux-gnu

WINE_SRC := source

$(eval $(call create-source-rules,wine,WINE))

$(WINE_SRC)/configure.ac: wine-source
$(WINE_SRC)/server/protocol.def: wine-source
$(WINE_SRC)/configure: $(WINE_SRC)/configure.ac
	cd $(WINE_SRC) && autoreconf -fi
	touch $@
$(WINE_SRC)/server/trace.c: $(WINE_SRC)/server/protocol.def
$(WINE_SRC)/server/request.h: $(WINE_SRC)/server/protocol.def
$(WINE_SRC)/include/wine/server_protocol.h: $(WINE_SRC)/server/protocol.def
	-cd $(WINE_SRC) && tools/make_requests && git diff | grep 'define SERVER_PROTOCOL' -C6 | tee requests.patch | patch -p1 -R
	-cd $(WINE_SRC) && [ -n "$(git diff)" ] && git apply requests.patch
	touch $@

define create-build-rules
# wine$(1)/Makefile: private SHELL := $(DOCKER_SHELL)
wine$(1)/Makefile: export CCACHE_BASEDIR := $$(abspath $$(WINE_SRC))
wine$(1)/Makefile: $$(WINE_SRC)/configure $$(shell mkdir -p wine$(1))
	cd wine$(1) && $$(abspath $$<) $(--quiet?) --cache-file="$(HOME)/.cache/autoconf/$(BUILD)$(1)" \
	                CC="$(strip $(CC$(1)))" CROSSCC="$(strip $(CROSSCC$(1)))" \
	                CXX="$(strip $(CXX$(1)))" CROSSCXX="$(strip $(CROSSCXX$(1)))" \
	                CFLAGS="$(strip $(CFLAGS) )" CROSSCFLAGS="$(strip $(CFLAGS) )" \
	                CXXFLAGS="$(strip $(CXXFLAGS))" CROSSCXXFLAGS="$(strip $(CXXFLAGS))" \
	                LDFLAGS="$(strip $(LDFLAGS) -L$(HOME)/Code/build-vkd3d/$(1)/.libs)" CROSSLDFLAGS="$(strip $(LDFLAGS))" \
	                VKD3D_CFLAGS="$(strip -I$(HOME)/Code/vkd3d/include -I$(HOME)/Code/build-vkd3d/$(1)/include)" \
	                $(CONFIGURE_OPTS) $(CONFIGURE_OPTS_$(1))

# wine$(1): private SHELL := $(DOCKER_SHELL)
.wine-build$(1): export CCACHE_BASEDIR := $$(abspath $$(WINE_SRC))
.wine-build$(1): wine$(1)/Makefile wine-source
	$$(MAKE) -C wine$(1) $(wine-goals)
	touch $$@

wine$(1): .wine-build$(1)
.PHONY: wine$(1)

wine-clean::
	$$(MAKE) -C wine$(1) clean
wine-distclean::
	rm -rf wine$(1) "$(HOME)/.cache/autoconf/$(BUILD)$(1)"
endef

$(eval $(call create-build-rules,32))
$(eval $(call create-build-rules,64))

.wine-build32: .wine-build64

wine32/Makefile: wine64/Makefile
wine32: wine64
wine: wine32 wine64

#%/tests: ENV := env DISPLAY=:2
%.ok: wine-source
# 	rm -rf $(HOME)/.wine-test && env WINEPREFIX=$(HOME)/.wine-test wine64/wine wineboot -u
# 	-env WINEPREFIX=$(HOME)/.wine-test wine64/server/wineserver -k
#	Xephyr -sw-cursor -br -ac -glamor -screen 1280x720 :2 & sleep 1
#	$(ENV) fvwm 2>/dev/null &
# 	$(ENV) metacity --no-composite --sm-disable 2>/dev/null &
# 	$(ENV) openbox --sm-disable 2>/dev/null &
	$(ENV) WINEPREFIX=$(HOME)/.wine-test $(MAKE) -C wine32/dlls/$(@D) $(@F) $(TESTFLAGS) || (killall Xephyr; exit 1)
	$(ENV) WINEPREFIX=$(HOME)/.wine-test $(MAKE) -C wine64/dlls/$(@D) $(@F) $(TESTFLAGS) || (killall Xephyr; exit 1)
# 	killall Xephyr
.PHONY: %.ok

.NOTPARALLEL:
.SUFFIXES:
