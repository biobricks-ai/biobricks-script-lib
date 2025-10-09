{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Test-Harness";
	version = "3.52";
	src = fetchurl {
		url = "mirror://cpan/authors/id/L/LE/LEONT/Test-Harness-3.52.tar.gz";
		hash = "sha256-j+Zc/AJh7TyKQ5XwUkKG9XGWaf4wX5sDsWzzaE1izXA=";
	};
	meta = {
		homepage = "http://testanything.org/";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
