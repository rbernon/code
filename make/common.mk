DEVEL_VERSION = stable

arch-shell = docker run --rm -e HOME -e USER -e USERID=$(shell id -u) -u $(shell id -u):$(shell id -g) \
                    -v $(HOME):$(HOME) -w $(CURDIR) rbernon/$(1):$(2) $(SHELL)

SHELL_x86_64 := $(call arch-shell,devel-x86_64,$(DEVEL_VERSION))
SHELL_i686 := $(call arch-shell,devel-i686,$(DEVEL_VERSION))

SHELL_llvm_x86_64 := $(call arch-shell,wine-llvm-x86_64,$(DEVEL_VERSION))
SHELL_llvm_i686 := $(call arch-shell,wine-llvm-i686,$(DEVEL_VERSION))

SHELL_proton := $(call arch-shell,proton,0.20210920.0-0)

nproc := $(shell nproc)
J = $(subst -j,,$(word 1,$(filter -j%,$(MAKEFLAGS) -j$(nproc))))
