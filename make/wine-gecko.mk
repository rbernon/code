include make/common.mk

nproc := $(shell nproc)
J = $(words 1,$(nproc) $(subst -j,,$(filter -j%,$(MAKEFLAGS))))

define wine-gecko-build
OBJ$(1) := $(abspath build-wine-gecko/$(1)-$(2))

wine-gecko: wine-gecko-$(1)-$(2)
wine-gecko-$(1)-$(2): private SHELL := $(SHELL_$(1))
wine-gecko-$(1)-$(2): $$(OBJ$(1))/Makefile
wine-gecko-$(1)-$(2):
	+env SHELL=/bin/sh MOZCONFIG="$$(OBJ$(1))/mozconfig" \
	$$(MAKE) -j$$(J) $$(MFLAGS) $$(MAKEOVERRIDES) -C $$(OBJ$(1))

	-find $$(OBJ$(1))/dist/firefox -type f '(' -iname '*.dll' -or -iname '*.exe' ')' -delete
	+env SHELL=/bin/sh MOZCONFIG="$$(OBJ$(1))/mozconfig" \
	$$(MAKE) -j$$(J) $$(MFLAGS) $$(MAKEOVERRIDES) -C $$(OBJ$(1))/browser/installer stage-package

	find $$(OBJ$(1))/dist/firefox -type f '(' -iname '*.dll' -or -iname '*.exe' ')' \
	    -printf '%p\0%p.debug\0' | \
	    xargs $(--verbose?) -0 -r -P$$(J) -n2 $(1)-$(2)-objcopy --file-alignment=4096 --only-keep-debug
	find $$(OBJ$(1))/dist/firefox -type f '(' -iname '*.dll' -or -iname '*.exe' ')' \
	    -printf '--add-gnu-debuglink=%p.debug\0%p\0' | \
	    xargs $(--verbose?) -0 -r -P$$(J) -n2 $(1)-$(2)-objcopy --file-alignment=4096 --strip-debug

.PHONY: wine-gecko-$(1)-$(2)

$$(OBJ$(1))/Makefile: private SHELL := $(SHELL_$(1))
$$(OBJ$(1))/Makefile: $$(OBJ$(1))/mozconfig
	env SHELL=/bin/sh MOZCONFIG="$$(OBJ$(1))/mozconfig" \
	wine-gecko/mach configure

$$(OBJ$(1))/mozconfig: | $$(shell mkdir -p "$$(OBJ$(1))")
	echo >$$@ "export CROSS_COMPILE=1"
	echo >>$$@ "export CC=$(1)-$(2)-gcc"
	echo >>$$@ "export CXX=$(1)-$(2)-g++"
	echo >>$$@ "export CFLAGS=\"$$(CFLAGS)\""
	echo >>$$@ "export LDFLAGS=\"$$(LDFLAGS_$(1)-$(2)) $$(LDFLAGS)\""
	echo >>$$@ "mk_add_options MOZ_OBJDIR=\"$$(OBJ$(1))\""
	echo >>$$@ "mk_add_options MOZ_PARALLEL_BUILD=$$(word 1,$$(subst -j,,$$(filter -j%,$$(MAKEFLAGS)) -j$(shell nproc)))"
	echo >>$$@ "ac_add_options --target=$(1)-$(2)"
	echo >>$$@ "ac_add_options --disable-debug"
	echo >>$$@ "ac_add_options --enable-optimize"
	echo >>$$@ "ac_add_options --disable-install-strip"
	cat >>$$@ wine-gecko/wine/mozconfig-common
endef

LDFLAGS_x86_64-w64-mingw32 := -Wl,--disable-dynamicbase,--disable-high-entropy-va

$(eval $(call wine-gecko-build,i686,w64-mingw32))
$(eval $(call wine-gecko-build,x86_64,w64-mingw32))
