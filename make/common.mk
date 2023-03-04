DEVEL_VERSION = experimental

arch-shell = docker run --rm -e HOME -e USER -e USERID=$(shell id -u) -u $(shell id -u):$(shell id -g) \
                    -v $(HOME):$(HOME) -w $(CURDIR) $(1):$(2) $(SHELL)

SHELL_x86_64 := $(call arch-shell,rbernon/devel-x86_64,$(DEVEL_VERSION))
SHELL_i686 := $(call arch-shell,rbernon/devel-i686,$(DEVEL_VERSION))

SHELL_llvm_x86_64 := $(call arch-shell,rbernon/wine-llvm-x86_64,$(DEVEL_VERSION))
SHELL_llvm_i686 := $(call arch-shell,rbernon/wine-llvm-i686,$(DEVEL_VERSION))

SHELL_proton := $(call arch-shell,registry.gitlab.steamos.cloud/proton/soldier/sdk,0.20220601.0-1)

nproc := $(shell nproc)
J = $(subst -j,,$(word 1,$(filter -j%,$(MAKEFLAGS) -j$(nproc))))
