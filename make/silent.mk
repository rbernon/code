ifneq ($(V),1)
.SILENT:
MAKEFLAGS += --quiet --no-print-directory
--quiet? := --quiet
else
TESTFLAGS := RUNTESTFLAGS=-v
MAKEFLAGS += V=1 VERBOSE=1 
MFLAGS += V=1 VERBOSE=1
--verbose? := --verbose
-v? := -v
endif
