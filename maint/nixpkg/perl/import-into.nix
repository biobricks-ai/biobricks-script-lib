{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Import-Into";
	version = "1.002005";
	src = fetchurl {
		url = "mirror://cpan/authors/id/H/HA/HAARG/Import-Into-1.002005.tar.gz";
		hash = "sha256-vZ53o/tmK0C0OxjTKAzTUu35+tjZQoPlGBgcwc6fBWc=";
	};
	propagatedBuildInputs = with perlPackages; [ ModuleRuntime ];
	meta = {
		description = "Import packages into other packages";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
