# Guard functions and targets for Makefile validation

# Guard function for required binaries
define require_bin
	@which $(1) > /dev/null || (echo "Error: $(1) is not installed" && exit 1)
endef

# Guard function for required environment variables
define require_env
	@if [ -z "$${$(1)}" ]; then echo "Error: $(1) environment variable is required" && exit 1; fi
endef

# Guard targets
.PHONY: _env-guard _bin-guard

_env-guard:

_bin-guard:

# Environment variable guard
# Usage: target: env-guard-VARNAME
env-guard-%: _env-guard
	$(call require_env,$*)

# Binary guard
# Usage: target: bin-guard-COMMAND
bin-guard-%: _bin-guard
	$(call require_bin,$*)
