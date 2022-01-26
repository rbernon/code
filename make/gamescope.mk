include make/common.mk

define gamescope-build
gamescope:: gamescope-$(1)
gamescope-$(1): SHELL := $(SHELL_$(1))
gamescope-$(1):
	env PATH=$(HOME)/.local/$(1)-linux-gnu/bin:$(PATH) \
	meson build-gamescope/$(1) gamescope \
	&& ninja -C build-gamescope/$(1)
endef

# $(eval $(call gamescope-build,i686))
$(eval $(call gamescope-build,x86_64))
