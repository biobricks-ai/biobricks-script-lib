{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Role-Hooks";
	version = "0.008";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/Role-Hooks-0.008.tar.gz";
		hash = "sha256-KNZuoKjcMGt22oP/CHlJPYCPcxhbz5xO03LzlG+1Q+w=";
	};
	buildInputs = with perlPackages; [ TestRequires ];
	propagatedBuildInputs = with perlPackages; [ ClassMethodModifiers ];
	meta = {
		homepage = "https://metacpan.org/release/Role-Hooks";
		description = "Role callbacks";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
