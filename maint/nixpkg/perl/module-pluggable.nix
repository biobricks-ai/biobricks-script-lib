{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Module-Pluggable";
	version = "6.3";
	src = fetchurl {
		url = "mirror://cpan/authors/id/S/SI/SIMONW/Module-Pluggable-6.3.tar.gz";
		hash = "sha256-WFErucZUdG0JN3cLmLVZswhy2FrCQHNIXlgwiQ3RsqA=";
	};
	meta = {
		description = "Automatically give your module the ability to have plugins";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
