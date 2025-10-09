{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Function-Parameters";
	version = "2.002006";
	src = fetchurl {
		url = "mirror://cpan/authors/id/M/MA/MAUKE/Function-Parameters-2.002006.tar.gz";
		hash = "sha256-7DbF2JHzGpCmttYZjZg6WXRgOtXrT5N2r4B6w3ST+aI=";
	};
	buildInputs = with perlPackages; [ TestFatal ];
	meta = {
		description = "Define functions and methods with parameter lists (\"subroutine signatures\")";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
