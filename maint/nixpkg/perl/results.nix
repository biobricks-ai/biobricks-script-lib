{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "results";
	version = "0.006";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/results-0.006.tar.gz";
		hash = "sha256-udGysegvVE1zS0bo0sEKcj/GVzkFUke64RvS3MArXqg=";
	};
	buildInputs = with perlPackages; [ TypeAPI ];
	propagatedBuildInputs = with perlPackages; [ DevelStrictMode ExporterTiny RoleTiny ];
	meta = {
		homepage = "https://metacpan.org/release/results";
		description = "Why throw exceptions when you can return them?";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
