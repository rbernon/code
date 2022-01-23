include make/common.mk

define mesa-build
mesa:: mesa-$(1)
mesa-$(1): SHELL := $(SHELL_$(1))
mesa-$(1):
	cd mesa \
	&& meson /tmp/build-mesa \
	  -Dplatforms=x11,wayland \
	  -Dgallium-drivers=radeonsi \
	  -Dvulkan-drivers=amd \
	  -Dglx=dri \
	  -Degl=enabled \
	  -Dgbm=enabled \
	  -Dopengl=true \
	  -Dlmsensors=false \
	  -Dllvm=enabled \
	  -Dprefix=$(HOME)/.local \
	  -Dlibdir=lib/$(1)-linux-gnu \
	  -Dbindir=$(1)-linux-gnu/bin \
	&& ninja -C /tmp/build-mesa install
.PHONY: mesa-$(1)
endef

$(eval $(call mesa-build,i686))
$(eval $(call mesa-build,x86_64))

MESON_CPU_i686 = x86
MESON_CPU_x86_64 = x86_64

define mesa-mingw-build
mesa:: mesa-$(1)
mesa-$(1)-$(2): SHELL := $(SHELL_$(1))
mesa-$(1)-$(2):
	-rm build-mesa/cross-$(1)-$(2).txt; mkdir -p build-mesa/
	echo >>build-mesa/cross-$(1)-$(2).txt "[binaries]" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "c = '$(1)-$(2)-gcc'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "cpp = '$(1)-$(2)-g++'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "ar = '$(1)-$(2)-ar'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "windres = '$(1)-$(2)-windres'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "strip = '$(1)-$(2)-strip'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "pkgconfig = 'pkg-config'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "[properties]" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "needs_exe_wrapper = true" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "c_args = ['-ggdb']" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "cpp_args = ['-ggdb']" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "link_args = ['-Wl,--file-alignment=4096']" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "[host_machine]" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "system = 'windows'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "cpu_family = '$$(MESON_CPU_$(1))'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "cpu = '$$(MESON_CPU_x86_$(1))'" && \
	echo >>build-mesa/cross-$(1)-$(2).txt "endian = 'little'" && \
	env PKG_CONFIG_LIBDIR=$(HOME)/.local/lib/$(1)-$(2)/pkgconfig \
	    PATH=$(HOME)/.local/$(1)-linux-gnu/bin:$(PATH) \
	meson build-mesa/$(1)-$(2) mesa \
	  --cross-file build-mesa/cross-$(1)-$(2).txt \
	  -Dgallium-drivers=zink \
	  -Dvalgrind=false \
	  -Dzlib=disabled \
	  -Dzstd=disabled \
	&& ninja -C build-mesa/$(1)-$(2)
endef

$(eval $(call mesa-mingw-build,i686,w64-mingw32))
$(eval $(call mesa-mingw-build,x86_64,w64-mingw32))
