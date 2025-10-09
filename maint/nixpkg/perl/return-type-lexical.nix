{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Return-Type-Lexical";
	version = "0.002";
	src = fetchurl {
		url = "mirror://cpan/authors/id/C/CC/CCM/Return-Type-Lexical-0.002.tar.gz";
		hash = "sha256-ERX212cb+117xKv+f1Eien5zDKiqIZPieFj/pjyPPlI=";
	};
	buildInputs = with perlPackages; [ TestException TypeTiny ];
	propagatedBuildInputs = with perlPackages; [ ReturnType ];
	meta = {
		homepage = "https://github.com/chazmcgarvey/Return-Type-Lexical";
		description = "Same thing as Return::Type, but lexical";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
