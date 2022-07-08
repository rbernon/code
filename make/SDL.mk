include make/common.mk

# CMAKE_SYSTEM_NAME_linux-gnu = Linux
CMAKE_SYSTEM_NAME_w64-mingw32 = Windows
CMAKE_C_FLAGS_w64-mingw32 = -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00
CMAKE_CXX_FLAGS_w64-mingw32 = -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00

define sdl-build
sdl: sdl-$(1)-$(2)
sdl-$(1)-$(2): SHELL := $(SHELL_$(1))
sdl-$(1)-$(2):
	cmake -Bbuild-sdl/$(1)-$(2) -HSDL \
	  -DCMAKE_BUILD_TYPE=Release \
	  -DCMAKE_C_COMPILER=$(1)-$(2)-gcc \
	  -DCMAKE_CXX_COMPILER=$(1)-$(2)-g++ \
	  -DCMAKE_C_FLAGS="$(CMAKE_C_FLAGS_$(2))" \
	  -DCMAKE_CXX_FLAGS="$(CMAKE_CXX_FLAGS_$(2))" \
	  $(if $(CMAKE_SYSTEM_NAME_$(2)),-DCMAKE_SYSTEM_NAME=$(CMAKE_SYSTEM_NAME_$(2)),) \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DCMAKE_INSTALL_LIBDIR=lib/$(1)-$(2) \
	  -DCMAKE_INSTALL_BINDIR=$(1)-$(2)/bin \
	  -DBUILD_LAYER_SUPPORT_FILES=ON \
	&& $$(MAKE) -j$$(J) -C build-sdl/$(1)-$(2) install VERBOSE=1
.PHONY: sdl-$(1)-$(2)
endef

$(eval $(call sdl-build,i686,w64-mingw32))
$(eval $(call sdl-build,x86_64,w64-mingw32))
$(eval $(call sdl-build,i686,linux-gnu))
$(eval $(call sdl-build,x86_64,linux-gnu))
