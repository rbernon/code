include make/common.mk

define gpuvis-build
gpuvis:: gpuvis-$(1)
gpuvis-$(1): SHELL := $(SHELL_$(1))
gpuvis-$(1):
	env PATH=$(HOME)/.local/$(1)-linux-gnu/bin:$(PATH) \
	meson build-gpuvis/$(1) gpuvis \
	&& ninja -C build-gpuvis/$(1)
endef

# $(eval $(call gpuvis-build,i686))
$(eval $(call gpuvis-build,x86_64))
