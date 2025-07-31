{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Unicode-EastAsianWidth";
	version = "12.0";
	src = fetchurl {
		url = "mirror://cpan/authors/id/A/AU/AUDREYT/Unicode-EastAsianWidth-12.0.tar.gz";
		hash = "sha256-Klv9kmxP5fd+YTfaLDGsJUUoKuX+xumvD91ANVWpD/Q=";
	};
	meta = {
		homepage = "https://github.com/audreyt/Unicode-EastAsianWidth/";
		description = "East Asian Width properties";
	};
}
