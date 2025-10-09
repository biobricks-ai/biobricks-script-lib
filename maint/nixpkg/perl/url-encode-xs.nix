{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "URL-Encode-XS";
	version = "0.03";
	src = fetchurl {
		url = "mirror://cpan/authors/id/C/CH/CHANSEN/URL-Encode-XS-0.03.tar.gz";
		hash = "sha256-1E9Ba9PljjszZqtCBwXaAscRj8hIqXzgiTZuoEYfqCM=";
	};
	propagatedBuildInputs = with perlPackages; [ URLEncode ];
	meta = {
		description = "XS implementation of URL::Encode";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
