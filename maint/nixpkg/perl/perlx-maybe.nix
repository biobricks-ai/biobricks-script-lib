{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "PerlX-Maybe";
	version = "1.202";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/PerlX-Maybe-1.202.tar.gz";
		hash = "sha256-IadPr7NaYtMwgpXBbLHgWWVDIH32fZdLPCUW6b3cowg=";
	};
	meta = {
		homepage = "https://metacpan.org/release/PerlX-Maybe";
		description = "Return a pair only if they are both defined";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
