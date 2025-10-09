{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "MooX-Struct";
	version = "0.020";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/MooX-Struct-0.020.tar.gz";
		hash = "sha256-4emwbUAxHND0mdJXxrZ13U5Mk2aT2ky3wleDr3fMXJ0=";
	};
	propagatedBuildInputs = with perlPackages; [ BHooksEndOfScope ExporterTiny Moo ObjectID TypeTiny namespaceautoclean ];
	meta = {
		homepage = "https://metacpan.org/release/MooX-Struct";
		description = "Make simple lightweight record-like structures that make sounds like cows";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
