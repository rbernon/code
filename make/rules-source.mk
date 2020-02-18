define create-source-rules
$(2)_SRC ?= src-$(1)

ifeq ($(3),nodelete)
$(1)-rsync := rsync --filter=:C --exclude=.git --info=name -Oarx $$(abspath $$($(2)))/ $$(abspath $$($(2)_SRC))
else
$(1)-rsync := rsync --filter=:C --exclude=.git --info=name -Oarx --delete $$(abspath $$($(2)))/ $$(abspath $$($(2)_SRC))
endif

.$(1)-source: $(MAKEFILE_DEP) $$(shell echo -n 'syncing $(1)... ' >&2 && \
                                       $$($(1)-rsync) | grep -q ^ && echo $(1)-rebuild && \
                                       echo 'done: rebuilding' >&2 || echo 'done: up to date' >&2)
	touch $$@
$(1)-source: .$(1)-source
.INTERMEDIATE: $(1)-source

$(1)-clean::
$(1)-distclean::
	rm -rf $$($(2)_SRC)
$(1)-rebuild::
	rm -f .$(1)-source

clean: $(1)-clean
distclean: $(1)-distclean
endef
