{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Cache-Cache";
	version = "1.08";
	src = fetchurl {
		url = "mirror://cpan/authors/id/R/RJ/RJBS/Cache-Cache-1.08.tar.gz";
		hash = "sha256-0sf9Xbpd0BC32JI1FokLtsz2tfGIzLafNcsP1sAx0eg=";
	};
	propagatedBuildInputs = with perlPackages; [ DigestSHA1 Error IPCShareLite ];
	meta = {
	};
}
