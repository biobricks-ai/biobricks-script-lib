{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlPackage {
	pname = "HTTP-Tiny";
	version = "0.090";
	src = fetchurl {
		url = "mirror://cpan/authors/id/H/HA/HAARG/HTTP-Tiny-0.090.tar.gz";
		hash = "sha256-+q9gs/m69Lj3A2MquiI2SKqliwEH5kylFe0AJHl42D4=";
	};
	meta = {
		homepage = "https://github.com/Perl-Toolchain-Gang/HTTP-Tiny";
		description = "A small, simple, correct HTTP/1.1 client";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
