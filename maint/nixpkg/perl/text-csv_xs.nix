{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Text-CSV_XS";
	version = "1.61";
	src = fetchurl {
		url = "mirror://cpan/authors/id/H/HM/HMBRAND/Text-CSV_XS-1.61.tgz";
		hash = "sha256-LLkVHowJOSH/aKueXDdve+AUoMsTk0LwwyKaxc3Z/Do=";
	};
	meta = {
		homepage = "https://metacpan.org/pod/Text::CSV_XS";
		description = "Comma-Separated Values manipulation routines";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
