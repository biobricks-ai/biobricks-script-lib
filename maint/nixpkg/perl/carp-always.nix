{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Carp-Always";
	version = "0.16";
	src = fetchurl {
		url = "mirror://cpan/authors/id/F/FE/FERREIRA/Carp-Always-0.16.tar.gz";
		hash = "sha256-mKoRSSFxwBb7CCdYGrH6XtAbHpnGNXSJ3fOoJzFYZvE=";
	};
	buildInputs = with perlPackages; [ TestBase ];
	meta = {
		description = "Warns and dies noisily with stack backtraces";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
