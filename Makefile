ifneq ($(V),1)
.SILENT:
endif
MAKEFLAGS += --no-print-directory


bin:
	install -m0755 -D bin/git-fip $(HOME)/.local/bin/git-fip
	install -m0755 -D bin/git-lmb $(HOME)/.local/bin/git-lmb
	install -m0755 -D bin/git-pab $(HOME)/.local/bin/git-pab
	install -m0755 -D bin/git-rab $(HOME)/.local/bin/git-rab
	install -m0644 -D bin/git-fip.completion.bash $(HOME)/.bash/completion/available/git-fip.completion.bash
	install -m0644 -D bin/git-lmb.completion.bash $(HOME)/.bash/completion/available/git-lmb.completion.bash
	install -m0644 -D bin/git-pab.completion.bash $(HOME)/.bash/completion/available/git-pab.completion.bash
	install -m0644 -D bin/git-rab.completion.bash $(HOME)/.bash/completion/available/git-rab.completion.bash
.PHONY: bin


build-proton/Makefile: $(shell mkdir -p build-proton)
	cd build-proton && ../proton/configure.sh \
	  --steam-runtime64=docker:rbernon/proton-amd64 \
	  --steam-runtime32=docker:rbernon/proton-i386 \
	  --steam-runtime=~/.steam/root/ubuntu12_32/steam-runtime \
	  --build-name=proton-local

proton: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 dist
.PHONY: proton
proton/wine: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 wine
.PHONY: proton/wine
proton/lsteamclient: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 lsteamclient
.PHONY: proton/lsteamclient
proton/install: build-proton/Makefile
	$(MAKE) -C build-proton UNSTRIPPED_BUILD=1 NO_MAKEFILE_DEPENDENCY=1 install
.PHONY: proton/install


define make-source-rules
$(3)$(1)::
	-git clone --quiet $(2)/$(1) $(3)$(1) 2>/dev/null
	git -C $(3)$(1) fetch --all
	git -C $(3)$(1) checkout --quiet $($(1)_VERSION)
endef

include make/vulkan.mk
include make/vulkan-tools.mk
include make/renderdoc.mk
include make/mesa.mk
include make/google-benchmark.mk
include make/benchmarks.mk
include make/dxvk.mk
include make/cairo.mk
include make/wine-gecko.mk
include make/faudio.mk
include make/ghidra.mk
include make/tests.mk
include make/nlopt.mk
include make/dlib.mk
include make/valgrind.mk
include make/gamescope.mk
include make/mono.mk
include make/gpuvis.mk
include make/mesa-demos.mk
