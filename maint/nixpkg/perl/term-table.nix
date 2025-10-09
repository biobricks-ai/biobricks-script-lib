{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Term-Table";
	version = "0.025";
	src = fetchurl {
		url = "mirror://cpan/authors/id/E/EX/EXODIST/Term-Table-0.025.tar.gz";
		hash = "sha256-Ln2DqL6XzbcdXrgWW16C3J4/T2JNuXKjzf1uun4ssp4=";
	};
	meta = {
		description = "Format a header and rows into a table";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
