include make/common.mk

MESON_CROSS_i686 = dxvk/build-win32.txt
MESON_CROSS_x86_64 = dxvk/build-win64.txt

define dxvk-build
dxvk:: dxvk-$(1)-$(2)
dxvk-$(1)-$(2): SHELL := $(SHELL_$(1))
dxvk-$(1)-$(2):
	env PATH=$(HOME)/.local/$(1)-linux-gnu/bin:$(PATH) \
	meson build-dxvk/$(1)-$(2) dxvk \
	  --cross-file $(MESON_CROSS_$(1)) \
	&& ninja -C build-dxvk/$(1)-$(2)
endef

$(eval $(call dxvk-build,i686,w64-mingw32))
$(eval $(call dxvk-build,x86_64,w64-mingw32))
