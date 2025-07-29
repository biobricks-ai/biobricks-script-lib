{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Test2-Tools-LoadModule";
	version = "0.008";
	src = fetchurl {
		url = "mirror://cpan/authors/id/W/WY/WYANT/Test2-Tools-LoadModule-0.008.tar.gz";
		hash = "sha256-ktG61LY3t+PEDi9NDxhSeFXpk/J6ZZUyJDPAVpZSCvI=";
	};
	buildInputs = with perlPackages; [ Test2Suite ];
	meta = {
		description = "Test whether a module can be successfully loaded";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
