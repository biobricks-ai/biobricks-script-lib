{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "kura";
	version = "0.09";
	src = fetchurl {
		url = "mirror://cpan/authors/id/K/KF/KFLY/kura-0.09.tar.gz";
		hash = "sha256-bXUpRUVrKW+tvO53qiEj4GwTEuDhiGxc91fgBrs/eoE=";
	};
	buildInputs = with perlPackages; [ ModuleBuildTiny ];
	meta = {
		homepage = "https://github.com/kfly8/kura";
		description = "Store constraints for Data::Checks, Type::Tiny, Moose, and more";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
	doCheck = false;
}
