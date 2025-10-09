{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "MooseX-ClassAttribute";
	version = "0.29";
	src = fetchurl {
		url = "mirror://cpan/authors/id/D/DR/DROLSKY/MooseX-ClassAttribute-0.29.tar.gz";
		hash = "sha256-YUTHfFJ3DU+DHK22yto3ElyAs+T/yyRtp+6dVZIu5yU=";
	};
	buildInputs = with perlPackages; [ TestFatal TestRequires ];
	propagatedBuildInputs = with perlPackages; [ Moose namespaceautoclean namespaceclean ];
	meta = {
		homepage = "http://metacpan.org/release/MooseX-ClassAttribute";
		description = "Declare class attributes Moose-style";
		license = lib.licenses.artistic2;
	};
}
