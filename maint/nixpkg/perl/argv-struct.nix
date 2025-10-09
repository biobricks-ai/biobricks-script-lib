{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "ARGV-Struct";
	version = "0.06";
	src = fetchurl {
		url = "mirror://cpan/authors/id/J/JL/JLMARTIN/ARGV-Struct-0.06.tar.gz";
		hash = "sha256-ou8XTjVjLBtuv/6Km2N0yKbUrf2jXSr+HnMIAkRLX2k=";
	};
	buildInputs = with perlPackages; [ TestException ];
	propagatedBuildInputs = with perlPackages; [ Moo TypeTiny ];
	meta = {
		description = "Parse complex data structures passed in ARGV";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
