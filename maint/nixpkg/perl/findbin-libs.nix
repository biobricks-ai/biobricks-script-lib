{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "FindBin-libs";
	version = "4.0.4";
	src = fetchurl {
		url = "mirror://cpan/authors/id/L/LE/LEMBARK/FindBin-libs-v4.0.4.tar.gz";
		hash = "sha256-LjnGY6ppuaY/dqBVA8Gn2yjfJmwzXY5IcLTkP3Q/G3I=";
	};
	propagatedBuildInputs = with perlPackages; [ DataDump FileCopyRecursiveReduced ];
	meta = {
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
