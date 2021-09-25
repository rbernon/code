include make/common.mk

CMAKE_SYSTEM_NAME_w64-mingw32 = Windows
CMAKE_C_FLAGS_w64-mingw32 = -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00
CMAKE_CXX_FLAGS_w64-mingw32 = -DWINVER=0x0A00 -D_WIN32_WINNT=0x0A00

define faudio-build
faudio: faudio-$(1)-$(2)
faudio-$(1)-$(2): SHELL := $(SHELL_$(1))
faudio-$(1)-$(2):
	cmake -Bbuild-faudio/$(1) -HFAudio \
	  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
	  -DCMAKE_C_COMPILER=$(1)-$(2)-gcc \
	  -DCMAKE_CXX_COMPILER=$(1)-$(2)-g++ \
	  -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--file-alignment=4096" \
	  -DCMAKE_C_FLAGS="$(CMAKE_C_FLAGS_$(2))" \
	  -DCMAKE_C_FLAGS_RELWITHDEBINFO="-ggdb -Wl,--file-alignment=4096 -O2" \
	  -DCMAKE_CXX_FLAGS="$(CMAKE_CXX_FLAGS_$(2))" \
	  -DCMAKE_CXX_FLAGS_RELWITHDEBINFO="-ggdb -Wl,--file-alignment=4096 -O2" \
	  $(if $(CMAKE_SYSTEM_NAME_$(2)),-DCMAKE_SYSTEM_NAME=$(CMAKE_SYSTEM_NAME_$(2)),) \
	  -DCMAKE_INSTALL_PREFIX=$(HOME)/.local \
	  -DCMAKE_INSTALL_LIBDIR=lib/$(1)-$(2) \
	  -DPLATFORM_WIN32=ON \
	  -DBUILD_CPP=OFF \
	&& $(MAKE) -j$(shell nproc) -C build-faudio/$(1) VERBOSE=1
.PHONY: faudio-$(1)-$(2)
endef

$(eval $(call faudio-build,i686,w64-mingw32))
$(eval $(call faudio-build,x86_64,w64-mingw32))
