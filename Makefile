# Note: GNU Makefile
ROOT_DIR := $(patsubst %/,%,$(dir $(realpath $(lastword $(MAKEFILE_LIST)))))

# Include standard helpers
include $(ROOT_DIR)/inc/make/help.mk
include $(ROOT_DIR)/inc/make/guard.mk

# Include component Makefiles

ifneq (,$(wildcard ./.env))
	include .env
	export
endif
