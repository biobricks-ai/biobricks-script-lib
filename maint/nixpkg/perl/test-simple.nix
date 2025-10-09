{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Test-Simple"; # nix-key: TestSimple13
	version = "1.302214";
	src = fetchurl {
		url = "mirror://cpan/authors/id/E/EX/EXODIST/Test-Simple-1.302214.tar.gz";
		hash = "sha256-YHfsw183sRs7dd8tC6G5ylQfHcJLK+jhW26R944uA/w=";
	};
	propagatedBuildInputs = with perlPackages; [ TermTable ];
	meta = {
		description = "Basic utilities for writing tests";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
	doCheck = false;
}
