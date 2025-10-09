{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Type-Tiny";
	version = "2.008003";
	src = fetchurl {
		url = "mirror://cpan/authors/id/T/TO/TOBYINK/Type-Tiny-2.008003.tar.gz";
		hash = "sha256-R+dqLAmmUIoPZbyIlUpuJhctkpeM/eXtuN2qIBPPBuc=";
	};
	propagatedBuildInputs = with perlPackages; [ ExporterTiny ];
	meta = {
		homepage = "https://typetiny.toby.ink/";
		description = "Tiny, yet Moo(se)-compatible type constraint";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
