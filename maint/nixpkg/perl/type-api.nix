{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Type-API";
	version = "1.001";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/Type-API-1.001.tar.gz";
		hash = "sha256-ZbeY/w6sCIC7KUhPPg9sglkw+NG/TiVhqacXGKAlP6U=";
	};
	meta = {
		homepage = "https://metacpan.org/release/Type-API";
		description = "A common interface for type constraints, based on observed patterns (documentation only)";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
