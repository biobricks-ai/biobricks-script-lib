{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "Object-ID";
	version = "0.1.2";
	src = fetchurl {
		url = "mirror://cpan/authors/id/M/MS/MSCHWERN/Object-ID-v0.1.2.tar.gz";
		hash = "sha256-V3YNaRk6dxiXOe3DRQm3Yk4J6ijJO0ynVT3wlreYe9I=";
	};
	propagatedBuildInputs = with perlPackages; [ HashFieldHash SubName ];
	meta = {
		description = "A unique identifier for any object";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
