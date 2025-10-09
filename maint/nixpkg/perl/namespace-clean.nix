{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "namespace-clean";
	version = "0.27";
	src = fetchurl {
		url = "mirror://cpan/authors/id/R/RI/RIBASUSHI/namespace-clean-0.27.tar.gz";
		hash = "sha256-ihCoPD4YPcePnnt6pNCbR8EftOfTozuaEpEv0i4xr50=";
	};
	propagatedBuildInputs = with perlPackages; [ BHooksEndOfScope PackageStash ];
	meta = {
		homepage = "http://search.cpan.org/dist/namespace-clean";
		description = "Keep imports and functions out of your namespace";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
