{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Types-Path-Tiny";
	version = "0.006";
	src = fetchurl {
		url = "mirror://cpan/authors/id/D/DA/DAGOLDEN/Types-Path-Tiny-0.006.tar.gz";
		hash = "sha256-WT/J+u28aSgGWcDM6FFo+OehcUys346ea3SJvhjf4oA=";
	};
	buildInputs = with perlPackages; [ Filepushd ];
	propagatedBuildInputs = with perlPackages; [ PathTiny TypeTiny ];
	meta = {
		homepage = "https://github.com/dagolden/types-path-tiny";
		description = "Path::Tiny types and coercions for Moose and Moo";
		license = lib.licenses.asl20;
	};
}
