{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Sub-HandlesVia";
	version = "0.050003";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/Sub-HandlesVia-0.050003.tar.gz";
		hash = "sha256-mLJw+JMpoVoppSCq3CZ2wKxUWvsk70BAG/Jok/DvJlU=";
	};
	buildInputs = with perlPackages; [ TestFatal TestRequires TryTiny ];
	propagatedBuildInputs = with perlPackages; [ ClassMethodModifiers ExporterTiny RoleHooks RoleTiny TypeTiny ];
	meta = {
		homepage = "https://metacpan.org/release/Sub-HandlesVia";
		description = "Alternative handles_via implementation";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
