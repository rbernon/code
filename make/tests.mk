include make/common.mk

define tests-build
tests: tests-$(1)-$(2)
tests-$(1)-$(2): SHELL := $(SHELL_$(1))
tests-$(1)-$(2):
	make -Ctests A=$(1)
.PHONY: tests-$(1)-$(2)
endef

$(eval $(call tests-build,i686))
$(eval $(call tests-build,x86_64))
