{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Text-Table-Tiny";
	version = "1.03";
	src = fetchurl {
		url = "mirror://cpan/authors/id/N/NE/NEILB/Text-Table-Tiny-1.03.tar.gz";
		hash = "sha256-C1qMJnj3nplpQFVoT1XxNLX/+3rl8AFqTkhmFAPG3l4=";
	};
	buildInputs = with perlPackages; [ TestFatal ];
	propagatedBuildInputs = with perlPackages; [ RefUtil StringTtyLength ];
	meta = {
		homepage = "https://github.com/neilb/Text-Table-Tiny";
		description = "Generate simple text tables from 2D arrays";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
