{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "Log-Any-Adapter-Screen";
	version = "0.141";
	src = fetchurl {
		url = "mirror://cpan/authors/id/P/PE/PERLANCAR/Log-Any-Adapter-Screen-0.141.tar.gz";
		hash = "sha256-UTk0sgjoUTiDE3rjGaspxecGy6w2kSQtvdu6hbeRZIc=";
	};
	propagatedBuildInputs = with perlPackages; [ LogAny ];
	meta = {
		homepage = "https://metacpan.org/release/Log-Any-Adapter-Screen";
		description = "(ADOPTME) Send logs to screen, with colors and some other features";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
