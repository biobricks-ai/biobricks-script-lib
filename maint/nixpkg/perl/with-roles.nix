{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "With-Roles";
	version = "0.001002";
	src = fetchurl {
		url = "mirror://cpan/authors/id/H/HA/HAARG/With-Roles-0.001002.tar.gz";
		hash = "sha256-4ug3T06bnhEuxf9B01A4nrFo5btyhTFPHCr/Nk7kwuA=";
	};
	buildInputs = with perlPackages; [ TestNeeds ];
	meta = {
		description = "Create role/class/object with composed roles";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
