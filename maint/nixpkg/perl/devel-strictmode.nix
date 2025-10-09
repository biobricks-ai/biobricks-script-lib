{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Devel-StrictMode";
	version = "0.003";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/Devel-StrictMode-0.003.tar.gz";
		hash = "sha256-sKfeX4qqzYMC5prl3wuP0VUKOij73wd8tXq8rezlZfA=";
	};
	meta = {
		homepage = "https://metacpan.org/release/Devel-StrictMode";
		description = "Determine whether strict (but slow) tests should be enabled";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
