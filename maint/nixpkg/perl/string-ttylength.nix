{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "String-TtyLength";
	version = "0.03";
	src = fetchurl {
		url = "mirror://cpan/authors/id/N/NE/NEILB/String-TtyLength-0.03.tar.gz";
		hash = "sha256-T+2vcgKFEdgOtq+6UjmT6aqiRdevVYNF1dTtRuLoLOE=";
	};
	propagatedBuildInputs = with perlPackages; [ UnicodeEastAsianWidth ];
	buildInputs = with perlPackages; [ Test2Suite ];
	meta = {
		homepage = "https://github.com/neilb/String-TtyLength";
		description = "Length or width of string excluding ANSI tty codes";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
