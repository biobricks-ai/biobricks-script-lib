{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "MooX-TypeTiny";
	version = "0.002003";
	src = fetchurl {
		url = "mirror://cpan/authors/id/H/HA/HAARG/MooX-TypeTiny-0.002003.tar.gz";
		hash = "sha256-2B4m/2+NsQJh8Ah/ltxUNn3LSanz3o1TI4+DTs4ZYks=";
	};
	buildInputs = with perlPackages; [ TestFatal ];
	propagatedBuildInputs = with perlPackages; [ Moo TypeTiny ];
	meta = {
		description = "Optimized type checks for Moo + Type::Tiny";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
