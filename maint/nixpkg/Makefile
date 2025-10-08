.PHONY: \
	nixpkg-perl-package-gen

PERL_NIX_DIR := $(ROOT_DIR)/maint/nixpkg/perl
PERL_NIX_FILES := $(wildcard $(PERL_NIX_DIR)/*.nix)

# - `tpage` requires Template::Toolkit
#     $ cpanm Template::Toolkit
# - `sponge` requires moreutils (pkg:deb/debian/moreutils)
$(ROOT_DIR)/maint/nixpkg/perl-package.nix: $(ROOT_DIR)/maint/nixpkg/perl-package.nix.tt2 $(PERL_NIX_FILES) | bin-guard-tpage
	[ -d $(PERL_NIX_DIR) ] \
		&& tpage --define perl_dir=$(PERL_NIX_DIR) $< \
		| perl -lpe 's/\s+$$//' | sponge $@

nixpkg-perl-package-gen: $(ROOT_DIR)/maint/nixpkg/perl-package.nix ## Generate perl-package.nix from template
