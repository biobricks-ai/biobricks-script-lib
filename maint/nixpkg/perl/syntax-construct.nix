{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Syntax-Construct";
	version = "1.043";
	src = fetchurl {
		url = "mirror://cpan/authors/id/C/CH/CHOROBA/Syntax-Construct-1.043.tar.gz";
		hash = "sha256-iqextHrplEoCJSK4yM2ePEdO0rIzqfFAmnwqCXYQe0w=";
	};
	meta = {
		description = "Explicitly state which non-feature constructs are used in the code";
		license = lib.licenses.artistic2;
	};
	doCheck = false;
}
