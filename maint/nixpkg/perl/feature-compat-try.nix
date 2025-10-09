{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "Feature-Compat-Try";
	version = "0.05";
	src = fetchurl {
		url = "mirror://cpan/authors/id/P/PE/PEVANS/Feature-Compat-Try-0.05.tar.gz";
		hash = "sha256-WaHHFzysMNsTHF8T+jhA9xhYju+bV5NS/+FWtVBxbXw=";
	};
	propagatedBuildInputs = with perlPackages; [ SyntaxKeywordTry ];
	meta = {
		description = "Make C<try/catch> syntax available";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
