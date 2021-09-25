include make/common.mk

define cairo-build
cairo-$(1): SHELL := $(SHELL_$(1))
cairo-$(1):
	cd cairo \
	&& meson /tmp/build-cairo \
	  -Dprefix=$(HOME)/.local \
	  -Dlibdir=lib/$(1)-linux-gnu \
	  -Dbindir=$(1)-linux-gnu/bin \
	&& ninja -C /tmp/build-cairo install
.PHONY: cairo-$(1)
endef

$(eval $(call cairo-build,i686))
$(eval $(call cairo-build,x86_64))

cairo: cairo-i686 cairo-x86_64
