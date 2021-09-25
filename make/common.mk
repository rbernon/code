DEVEL_VERSION = local

arch-shell = docker run --rm -e HOME -e USER -e USERID=$(shell id -u) -u $(shell id -u):$(shell id -g) \
                    -v $(HOME):$(HOME) -w $(CURDIR) rbernon/$(1):$(DEVEL_VERSION) $(SHELL)

SHELL_x86_64 := $(call arch-shell,devel-x86_64)
SHELL_i686 := $(call arch-shell,devel-i686)

SHELL_llvm_x86_64 := $(call arch-shell,wine-llvm-x86_64)
SHELL_llvm_i686 := $(call arch-shell,wine-llvm-i686)
