{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Pithub";
	version = "0.01043";
	src = fetchurl {
		url = "mirror://cpan/authors/id/O/OA/OALDERS/Pithub-0.01043.tar.gz";
		hash = "sha256-X3mLcSpt5Bk0rB8F6DOngsRwVhZQ5fUUwtwaXP0OZyM=";
	};
	buildInputs = with perlPackages; [ ImportInto PathTiny TestDifferences TestException TestMost TestNeeds ];
	propagatedBuildInputs = with perlPackages; [ CHI HTTPMessage JSONMaybeXS LWP Moo URI ];
	meta = {
		homepage = "https://github.com/plu/Pithub";
		description = "Github v3 API";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
	doCheck = false;
}
