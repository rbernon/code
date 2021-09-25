include make/common.mk

define ghidra-build
ghidra: ghidra-$(1)-$(2)
ghidra-$(1)-$(2): SHELL := $(SHELL_$(1))
ghidra-$(1)-$(2):
	$(MAKE) -j$(shell nproc) -Cghidra $(1) VERBOSE=1
.PHONY: ghidra-$(1)-$(2)
endef

$(eval $(call ghidra-build,i686,w64-mingw32))
$(eval $(call ghidra-build,x86_64,w64-mingw32))
