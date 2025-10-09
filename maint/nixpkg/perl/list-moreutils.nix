{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "List-MoreUtils";
	version = "0.430";
	src = fetchurl {
		url = "mirror://cpan/authors/id/R/RE/REHSACK/List-MoreUtils-0.430.tar.gz";
		hash = "sha256-Y7H3hCzULZtTjR404DMN5f8VWeTCc3NCUGQYJ29kZSc=";
	};
	buildInputs = with perlPackages; [ TestLeakTrace ];
	propagatedBuildInputs = with perlPackages; [ ExporterTiny ListMoreUtilsXS ];
	meta = {
		homepage = "https://metacpan.org/release/List-MoreUtils";
		description = "Provide the stuff missing in List::Util";
		license = lib.licenses.asl20;
	};
}
