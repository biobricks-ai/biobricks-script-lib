{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "lib-projectroot";
	version = "1.010";
	src = fetchurl {
		url = "mirror://cpan/authors/id/D/DO/DOMM/lib-projectroot-1.010.tar.gz";
		hash = "sha256-uoF7GdaOT+xrz+vOb4bwpvuj1PeWAZ5Gnbq91FewUus=";
	};
	buildInputs = with perlPackages; [ TestOutput ];
	propagatedBuildInputs = with perlPackages; [ locallib ];
	meta = {
		homepage = "https://github.com/domm/lib-projectroot";
		description = "Easier loading of a project's local libs";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
