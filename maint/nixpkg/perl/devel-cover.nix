{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Devel-Cover";
	version = "1.51";
	src = fetchurl {
		url = "mirror://cpan/authors/id/P/PJ/PJCJ/Devel-Cover-1.51.tar.gz";
		hash = "sha256-vxk2l3Anus0kPRcTd4UHFJotomnn5ynPcIsYYN7o9Yo=";
	};
	propagatedBuildInputs = with perlPackages; [ HTMLParser ];
	meta = {
		homepage = "https://pjcj.net/perl.html";
		description = "Code coverage metrics for Perl";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
	doCheck = false;
}
