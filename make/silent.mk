ifneq ($(V),1)
.SILENT:
MAKEFLAGS += --quiet --no-print-directory
--quiet? := --quiet
else
MAKEFLAGS += V=1 VERBOSE=1 RUNTESTFLAGS="-P wine"
MFLAGS += V=1 VERBOSE=1 RUNTESTFLAGS="-P wine"
-v? := -v
endif
