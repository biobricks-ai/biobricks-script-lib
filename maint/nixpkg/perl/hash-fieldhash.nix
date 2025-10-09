{ perlPackages, fetchurl, lib }:

perlPackages.buildPerlModule {
	pname = "Hash-FieldHash";
	version = "0.15";
	src = fetchurl {
		url = "mirror://cpan/authors/id/G/GF/GFUJI/Hash-FieldHash-0.15.tar.gz";
		hash = "sha256-XFFXB6VDN5alaXsRjdvx8hbRPFzVLytkKS5299m36PE=";
	};
	buildInputs = with perlPackages; [ TestLeakTrace ];
	meta = {
		homepage = "https://github.com/gfx/p5-Hash-FieldHash";
		description = "Lightweight field hash for inside-out objects";
		license = with lib.licenses; [ artistic1 gpl1Plus ];
	};
}
