MAKEFLAGS += -rR
.NOTPARALLEL:
.SUFFIXES:

include ../make/silent.mk
include ../make/rules-source.mk

CC = gcc
CC64 ?= x86_64-linux-gnu-$(CC)
CC32 ?= i686-linux-gnu-$(CC)

VKD3D_SRC := source

all: vkd3d32 vkd3d64

DOCKER_SHELL := docker run --rm --init --privileged --cap-add=SYS_ADMIN --security-opt apparmor:unconfined \
                  -v $(HOME):$(HOME) -v /tmp:/tmp -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro  -v /etc/shadow:/etc/shadow:ro \
                  -w $(CURDIR) -e HOME=$(HOME) -e PATH=$(PATH) -u $(shell id -u):$(shell id -g) -h $(shell hostname)


# 32/Makefile: SHELL := $(DOCKER_SHELL) rbernon/proton-i386:latest /bin/bash
# 32/.build: SHELL := $(DOCKER_SHELL) rbernon/proton-i386:latest /bin/bash

# 64/Makefile: SHELL := $(DOCKER_SHELL) rbernon/proton-amd64:latest /bin/bash
# 64/.build: SHELL := $(DOCKER_SHELL) rbernon/proton-amd64:latest /bin/bash

$(eval $(call create-source-rules,vkd3d,VKD3D))

define create-build-rules
$(1)$(3)/Makefile: export CCACHE_BASEDIR := $$(abspath $$($(2)_SRC))
$(1)$(3)/Makefile: $$($(2)_SRC)/configure $$(shell mkdir -p $(1)$(3)) | $(1)-source
	cd $(1)$(3) && env CC=$$(CC$(3)) "$$(abspath $$<)" $$(--quiet?) -C --prefix=$$(HOME)/.local WIDL=$$(HOME)/Code/build-wine/wine64/tools/widl/widl LDFLAGS=-lpthread

.$(1)-build$(3): export CCACHE_BASEDIR := $$(abspath $$($(2)_SRC))
.$(1)-build$(3): $(1)$(3)/Makefile $(1)-source
	$$(MAKE) -C $(1)$(3)
	touch $$@

$(1)$(3): .$(1)-build$(3)
.PHONY: $(1)$(3)

$(1)-clean::
	$$(MAKE) -C $(1)$(3) clean
$(1)-distclean::
	rm -rf $(1)$(3)

clean: $(1)-clean
distclean: $(1)-distclean
endef

$(eval $(call create-build-rules,vkd3d,VKD3D,32))
$(eval $(call create-build-rules,vkd3d,VKD3D,64))
